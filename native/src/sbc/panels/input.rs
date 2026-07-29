use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::cursor::drag_cursor::DragCursor;
use crate::sbc::panels::field::{
    ChangeQueue, CommitRequest, InteractionEvent, InteractionQueue, NumericDragPresentation,
};
use crate::sbc::panels::view::PanelView;

/// The everyday rate is deliberately the old Shift precision rate. Numeric
/// fields otherwise cross their useful range too abruptly on ordinary drags.
const NORMAL_DRAG_MULT: f32 = 0.1;
/// Shift is a further precision mode, five times slower than normal drag.
const FINE_DRAG_MULT: f32 = NORMAL_DRAG_MULT / 5.0;

/// Which field the pointer is on, and whether RmlUi has called it a drag yet.
enum DragState {
    Idle,
    /// Pressed. Becomes a drag if RmlUi says so, a click if it does not.
    Pending {
        field: String,
    },
    /// RmlUi is dragging: the value follows the cursor until `dragend`.
    Dragging {
        field: String,
    },
}

/// Action to perform after processing interaction events.
pub(crate) enum PendingAction {
    DragStart(String),
    DragEnd(String),
    DragMove { field: String, dx: f32 },
    ClickEdit(String),
    NumericDragPresentation(NumericDragPresentation),
}

/// Handles all engine input callbacks (mouse, keyboard, text) for the panel.
/// Owns the drag state machine and the shared event queues.
pub(crate) struct PanelInput {
    drag: DragState,
    mouse_captured: bool,
    last_mouse_x: f32,
    last_mouse_y: f32,
    press_anchor: Option<(i32, i32)>,
    cursor_x: f32,
    cursor_y: f32,
    changes: ChangeQueue,
    interactions: InteractionQueue,
    /// Pins and hides the pointer while a field is being dragged.
    cursor: DragCursor,
}

impl PanelInput {
    pub(crate) fn new(changes: ChangeQueue, interactions: InteractionQueue) -> Self {
        PanelInput {
            drag: DragState::Idle,
            mouse_captured: false,
            last_mouse_x: 0.0,
            last_mouse_y: 0.0,
            press_anchor: None,
            cursor_x: 0.0,
            cursor_y: 0.0,
            changes,
            interactions,
            cursor: DragCursor::default(),
        }
    }

    /// Forget in-flight input. The elements a drag or a queued event referred
    /// to are gone once RmlUi has been torn down and rebuilt.
    pub(crate) fn reset(&mut self) {
        self.drag = DragState::Idle;
        self.mouse_captured = false;
        self.press_anchor = None;
        self.changes.borrow_mut().clear();
        self.interactions.borrow_mut().clear();
    }

    pub(crate) fn changes(&self) -> &ChangeQueue {
        &self.changes
    }
    pub(crate) fn interactions(&self) -> &InteractionQueue {
        &self.interactions
    }

    /// Numeric fields publish presentation updates while dragging. Drain those immediately so the overlay appears in the same
    /// frame as the value change, rather than one frame later.
    pub(crate) fn take_numeric_drag_presentations(&self) -> Vec<NumericDragPresentation> {
        let mut events = self.interactions.borrow_mut();
        let mut presentations = Vec::new();
        events.retain(|event| match event {
            InteractionEvent::NumericDragPresentation(presentation) => {
                presentations.push(presentation.clone());
                false
            }
            _ => true,
        });
        presentations
    }

    // ── Per-tick processing (called from manager) ──────────────────

    /// Drain interaction events and update drag state. Returns actions to
    /// execute on the editor (drag-end or click-to-edit).
    /// Cache the cursor position each tick; a press event carries no coordinates.
    pub(crate) fn set_cursor(&mut self, interface: &NativeInterfaceRef) {
        if let Ok(mouse) = interface.input().get_mouse_state() {
            self.cursor_x = mouse.x;
            self.cursor_y = mouse.y;
        }
    }

    /// Turn the field's pointer events into drag/click actions.
    ///
    /// RmlUi decides what is a drag: it captures the pointer on `dragstart` and
    /// delivers `dragend` wherever the button is released, even off the panel.
    /// A press that never became a drag is a click, and opens the inline editor.
    pub(crate) fn process_interactions(
        &mut self,
        interface: &NativeInterfaceRef,
    ) -> Vec<PendingAction> {
        let events: Vec<InteractionEvent> = self.interactions.borrow_mut().drain(..).collect();
        let mut actions = Vec::new();
        for event in events {
            match event {
                InteractionEvent::PointerDown { field, anchor } => {
                    self.drag = DragState::Pending { field };
                    self.press_anchor =
                        anchor.or(Some((self.cursor_x as i32, self.cursor_y as i32)));
                }
                InteractionEvent::DragStart { field } => {
                    // Pin and hide the pointer for the length of the drag.
                    self.cursor.begin(
                        interface,
                        self.press_anchor
                            .unwrap_or((self.cursor_x as i32, self.cursor_y as i32)),
                    );
                    self.drag = DragState::Dragging {
                        field: field.clone(),
                    };
                    // The manager records the value the drag began from, so undo
                    // can return to it.
                    actions.push(PendingAction::DragStart(field));
                }
                InteractionEvent::DragEnd { field } => {
                    self.finish_drag(interface, field, &mut actions);
                }
                InteractionEvent::DragMove { field, dx } => {
                    if matches!(&self.drag, DragState::Dragging { field: active } if active == &field)
                    {
                        let multiplier = drag_multiplier(self.fine_drag_multiplier(interface));
                        actions.push(PendingAction::DragMove {
                            field,
                            dx: dx * multiplier,
                        });
                    }
                }
                InteractionEvent::PointerUp { field } => {
                    // RmlUi normally sends `dragend` after `mouseup`, but focus
                    // changes and interrupted input can skip it. The matching
                    // primary-button release is sufficient to finish the drag;
                    // a later dragend is deliberately a no-op.
                    if matches!(&self.drag, DragState::Dragging { field: active } if active == &field)
                    {
                        self.finish_drag(interface, field, &mut actions);
                        continue;
                    }
                    // Only a press that never became a drag is a click. RmlUi
                    // sends `mouseup` after `dragend` too, and that must not
                    // reopen the editor on the field just dragged.
                    if let DragState::Pending { field: pending } =
                        std::mem::replace(&mut self.drag, DragState::Idle)
                    {
                        if pending == field {
                            self.press_anchor = None;
                            actions.push(PendingAction::ClickEdit(pending));
                        }
                    }
                }
                InteractionEvent::NumericDragPresentation(presentation) => {
                    actions.push(PendingAction::NumericDragPresentation(presentation));
                }
            }
        }
        if matches!(self.drag, DragState::Dragging { .. }) {
            self.cursor.reassert(interface);
        }
        actions
    }

    /// Drain commit requests.
    pub(crate) fn drain_changes(&mut self) -> Vec<CommitRequest> {
        self.changes.borrow_mut().drain(..).collect()
    }

    // ── Input callbacks ────────────────────────────────────────────

    /// RmlUi owns captured numeric drags and dispatches their exact motion to
    /// `on_numeric_pointer`. Do not poll or reinterpret this callback: doing
    /// so is what turned a small move into a large value jump.
    pub(crate) fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        self.last_mouse_y = y as f32;

        // A drag owns the pointer. Its RmlUi listener has already consumed and
        // warped the exact motion before this callback can run.
        if !matches!(self.drag, DragState::Idle) {
            return Ok(true);
        }

        self.forward_mouse_move(interface, view, x, y)
    }

    pub(crate) fn mouse_press(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<bool, Error> {
        self.last_mouse_x = x as f32;
        self.last_mouse_y = y as f32;
        // Mouse callbacks and RmlUi use top-origin Y, while the native input
        // API and `warp_mouse` use the bottom-origin convention exposed by Lua.
        // Store the latter: this anchor is passed straight back to the engine
        // when the drag is released.
        self.press_anchor = interface
            .display()
            .get_view_geometry()
            .ok()
            .map(|geometry| (x, geometry.viewSizeY - y - 1));
        let Some(ctx) = view.context_handle() else {
            return Ok(false);
        };
        // `mouse_captured` records where the previous move was routed. It can
        // remain set after a modal closes, so it must not make an unrelated
        // fresh press over the map belong to RmlUi. Live field drags are the
        // only interaction that intentionally keeps a press outside the UI.
        if !view.contains(interface, x, y)
            && !view.contains_modal(interface, x, y)
            && self.drag_field().is_none()
        {
            self.mouse_captured = false;
            return Ok(false);
        }
        interface
            .rml_ui()
            .context_process_mouse_move(ctx, x as f32, y as f32, 0)?;
        self.mouse_captured = true;
        let _ = interface
            .rml_ui()
            .context_process_mouse_button_down(ctx, button - 1, 0)?;

        // The press is inside the panel, so the panel owns it -- always. The
        // engine only sends `mouse_release` to whoever claimed the press, and
        // RmlUi's return value is not "I consumed it" (it reports the opposite),
        // so reporting it here meant a press on a field was disowned: no release
        // ever came back, and a drag released outside the panel stayed stuck in
        // drag mode forever.
        Ok(true)
    }

    pub(crate) fn mouse_release(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        x: i32,
        y: i32,
        button: i32,
    ) -> Result<(), Error> {
        self.last_mouse_x = x as f32;
        self.last_mouse_y = y as f32;
        let Some(ctx) = view.context_handle() else {
            return Ok(());
        };
        interface
            .rml_ui()
            .context_process_mouse_move(ctx, x as f32, y as f32, 0)?;
        let _ = interface
            .rml_ui()
            .context_process_mouse_button_up(ctx, button - 1, 0);
        self.mouse_captured = interface
            .rml_ui()
            .context_is_mouse_interacting(ctx)
            .unwrap_or(false);
        Ok(())
    }

    pub(crate) fn mouse_wheel(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        up: bool,
        value: f32,
    ) -> Result<bool, Error> {
        let Some(ctx) = view.context_handle() else {
            return Ok(false);
        };
        let mouse = interface.input().get_mouse_state()?;
        if !view.contains(interface, mouse.x as i32, mouse.y as i32) {
            return Ok(false);
        }
        let delta = if up { value } else { -value };
        interface
            .rml_ui()
            .context_process_mouse_wheel(ctx, delta, 0.0, 0)
    }

    /// A new mouse press interrupts any numeric gesture currently in flight.
    ///
    /// This is deliberately independent of where the new press lands. The
    /// panel listener also observes clicks on the map, whereas RmlUi only sees
    /// the panel context; waiting for an RmlUi `dragend` therefore left the
    /// application-side visual state live forever after a map right-click.
    /// Return the ordinary drag-end action so the manager commits the current
    /// preview exactly once and hides the overlay in this same input call.
    pub(crate) fn interrupt_drag(
        &mut self,
        interface: &NativeInterfaceRef,
        context: Option<u64>,
    ) -> Option<PendingAction> {
        if matches!(self.drag, DragState::Idle) {
            return None;
        }

        // RmlUi also keeps its own button/drag bookkeeping. Give it a synthetic
        // primary release, then discard its now-stale callback events: the
        // application state below is the authoritative cancellation and no old
        // presentation update may remount the overlay afterwards.
        if let Some(context) = context {
            let rml = interface.rml_ui();
            let _ = rml.context_set_pointer_capture(context, 0, 0, false);
            let _ = rml.context_process_mouse_button_up(context, 0, 0);
        }
        self.interactions.borrow_mut().clear();
        self.press_anchor = None;

        match std::mem::replace(&mut self.drag, DragState::Idle) {
            DragState::Dragging { field } => {
                self.cursor.cancel(interface);
                Some(PendingAction::DragEnd(field))
            }
            // A press that never reached RmlUi's drag threshold must not turn
            // into a click-to-edit merely because another button interrupted it.
            DragState::Pending { .. } | DragState::Idle => None,
        }
    }

    fn drag_field(&self) -> Option<&str> {
        match &self.drag {
            DragState::Pending { field, .. } | DragState::Dragging { field } => Some(field),
            DragState::Idle => None,
        }
    }

    fn finish_drag(
        &mut self,
        interface: &NativeInterfaceRef,
        field: String,
        actions: &mut Vec<PendingAction>,
    ) {
        if !matches!(&self.drag, DragState::Dragging { field: active } if active == &field) {
            return;
        }
        self.cursor.end(interface);
        self.drag = DragState::Idle;
        self.press_anchor = None;
        actions.push(PendingAction::DragEnd(field));
    }

    fn fine_drag_multiplier(&self, interface: &NativeInterfaceRef) -> bool {
        interface
            .input()
            .get_mod_key_state()
            .map(|(_, _, _, shift)| shift)
            .unwrap_or(false)
    }

    fn forward_mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        let Some(ctx) = view.context_handle() else {
            return Ok(false);
        };
        let inside = view.contains(interface, x, y);
        let modal = view.contains_modal(interface, x, y);
        let interacting = interface.rml_ui().context_is_mouse_interacting(ctx)?;
        if !inside && !modal && !interacting {
            if self.mouse_captured {
                let _ = interface.rml_ui().context_process_mouse_leave(ctx);
            }
            self.mouse_captured = false;
            return Ok(false);
        }
        interface
            .rml_ui()
            .context_process_mouse_move(ctx, x as f32, y as f32, 0)?;
        self.mouse_captured = inside || modal || interacting;
        Ok(self.mouse_captured)
    }
}

fn drag_multiplier(shift_held: bool) -> f32 {
    if shift_held {
        FINE_DRAG_MULT
    } else {
        NORMAL_DRAG_MULT
    }
}

#[cfg(test)]
mod tests {
    use super::{drag_multiplier, FINE_DRAG_MULT, NORMAL_DRAG_MULT};

    #[test]
    fn shift_drag_is_five_times_more_precise() {
        assert_eq!(drag_multiplier(false), NORMAL_DRAG_MULT);
        assert_eq!(drag_multiplier(true), FINE_DRAG_MULT);
        assert_eq!(NORMAL_DRAG_MULT / FINE_DRAG_MULT, 5.0);
    }
}
