use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlPointerCaptureStatus,
};

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
/// Ignore ordinary press jitter, but retain it until it reaches this threshold
/// so a slow deliberate drag still starts smoothly.
const DRAG_START_THRESHOLD_PX: i32 = 3;

/// Which field owns the pointer, and whether this module has called it a drag.
#[derive(Debug)]
enum DragState {
    Idle,
    /// Pressed. Becomes a drag after enough engine-captured relative motion.
    Pending {
        field: String,
    },
    /// The value follows engine-captured relative motion until primary release.
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
    pending_drag_dx: i32,
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
            pending_drag_dx: 0,
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
        self.pending_drag_dx = 0;
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

    /// Turn engine capture lifecycle and field presses into editor actions.
    pub(crate) fn process_interactions(
        &mut self,
        interface: &NativeInterfaceRef,
        context: Option<u64>,
    ) -> Result<Vec<PendingAction>, Error> {
        let events: Vec<InteractionEvent> = self.interactions.borrow_mut().drain(..).collect();
        let mut actions = Vec::new();
        for event in events {
            match event {
                InteractionEvent::Click { field } => actions.push(PendingAction::ClickEdit(field)),
                InteractionEvent::PointerDown { field } => {
                    // A second press can arrive before a previous capture end
                    // has been observed by this update. Close the old gesture
                    // locally; the engine endpoint remains the source of truth
                    // for its normal path.
                    if let Some(action) = self.interrupt_drag(interface) {
                        actions.push(action);
                    }
                    self.drag = DragState::Pending { field };
                    self.pending_drag_dx = 0;
                }
                InteractionEvent::NumericDragPresentation(presentation) => {
                    actions.push(PendingAction::NumericDragPresentation(presentation));
                }
            }
        }
        self.drain_pointer_delta(interface, context, &mut actions)?;
        if matches!(self.drag, DragState::Dragging { .. }) {
            self.cursor.reassert(interface);
        }
        Ok(actions)
    }

    /// Drain commit requests.
    pub(crate) fn drain_changes(&mut self) -> Vec<CommitRequest> {
        self.changes.borrow_mut().drain(..).collect()
    }

    /// The screen-level numeric presentation is meaningful only after the
    /// pending press has crossed the drag threshold.
    pub(crate) fn is_dragging(&self) -> bool {
        matches!(self.drag, DragState::Dragging { .. })
    }

    // ── Input callbacks ────────────────────────────────────────────

    /// The engine consumes a numeric drag before panel callbacks see the motion.
    /// Other panel input still uses the ordinary RmlUi forwarding path.
    pub(crate) fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        // A numeric capture owns the pointer; its relative movement is read in
        // `process_interactions`, not interpreted from this absolute position.
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
        // Numeric captures are ended by the engine lifecycle in `update`.
        // Never forward their absolute release coordinates back into RmlUi:
        // that would make completion depend on whatever element is hit there.
        if !matches!(self.drag, DragState::Idle) {
            return Ok(());
        }
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
    /// The engine has already recorded its cancellation; this local close only
    /// makes the visual state disappear in the same input callback.
    pub(crate) fn interrupt_drag(
        &mut self,
        interface: &NativeInterfaceRef,
    ) -> Option<PendingAction> {
        if matches!(self.drag, DragState::Idle) {
            return None;
        }

        self.interactions.borrow_mut().clear();
        self.pending_drag_dx = 0;

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
            DragState::Pending { field } | DragState::Dragging { field } => Some(field),
            DragState::Idle => None,
        }
    }

    /// Convert engine-captured movement into the application-owned gesture.
    /// RmlUi never receives this motion, which prevents both its competing
    /// drag lifecycle and hover/tooltips on controls the physical cursor crossed.
    fn drain_pointer_delta(
        &mut self,
        interface: &NativeInterfaceRef,
        context: Option<u64>,
        actions: &mut Vec<PendingAction>,
    ) -> Result<RmlPointerCaptureStatus, Error> {
        let Some(context) = context else {
            return Ok(RmlPointerCaptureStatus::None);
        };
        let delta = interface.rml_ui().take_pointer_capture_delta(context)?;
        let delta_x = delta.delta_x;
        if delta_x != 0 {
            let field = match &self.drag {
                DragState::Idle => None,
                DragState::Pending { field } => {
                    self.pending_drag_dx += delta_x;
                    (self.pending_drag_dx.abs() >= DRAG_START_THRESHOLD_PX).then(|| field.clone())
                }
                DragState::Dragging { field } => Some(field.clone()),
            };

            if let Some(field) = field {
                if matches!(self.drag, DragState::Pending { .. }) {
                    self.cursor.begin(interface);
                    self.drag = DragState::Dragging {
                        field: field.clone(),
                    };
                    actions.push(PendingAction::DragStart(field.clone()));
                }

                let raw_dx = std::mem::take(&mut self.pending_drag_dx);
                let dx = if raw_dx != 0 { raw_dx } else { delta_x };
                actions.push(PendingAction::DragMove {
                    field,
                    dx: dx as f32 * drag_multiplier(self.fine_drag_multiplier(interface)),
                });
            }
        }

        match delta.status {
            RmlPointerCaptureStatus::Active | RmlPointerCaptureStatus::None => {}
            RmlPointerCaptureStatus::Released => self.release_drag_or_click(interface, actions),
            RmlPointerCaptureStatus::Cancelled => {
                if let Some(action) = self.interrupt_drag(interface) {
                    actions.push(action);
                }
            }
        }
        Ok(delta.status)
    }

    fn release_drag_or_click(
        &mut self,
        interface: &NativeInterfaceRef,
        actions: &mut Vec<PendingAction>,
    ) {
        match std::mem::replace(&mut self.drag, DragState::Idle) {
            DragState::Dragging { field } => {
                self.cursor.end(interface);
                self.pending_drag_dx = 0;
                actions.push(PendingAction::DragEnd(field));
            }
            DragState::Pending { field } => {
                self.pending_drag_dx = 0;
                actions.push(PendingAction::ClickEdit(field));
            }
            DragState::Idle => {}
        }
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
