use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::{ChangeQueue, CommitRequest, InteractionEvent, InteractionQueue};
use crate::sbc::panels::view::PanelView;

const DRAG_THRESHOLD: f32 = 3.0;
const FINE_DRAG_MULT: f32 = 0.1;
/// Mask bit for Shift in `get_mod_key_state`.
const SHIFT_BIT: u32 = 1;

/// Three-state drag tracker.
enum DragState {
    Idle,
    /// Mouse pressed but threshold not yet exceeded.
    Pending {
        field: String,
        start_x: f32,
    },
    /// Dragging is active; value updates every mouse-move.
    Dragging {
        field: String,
    },
}

/// Action to perform after processing interaction events.
pub(crate) enum PendingAction {
    DragEnd(String),
    ClickEdit(String),
}

/// What one `tick_drag` did.
pub(crate) enum DragTick {
    Idle,
    /// A drag just crossed the threshold; the field still holds its old value.
    Started(String),
    /// The field's value moved and should be previewed.
    Moved(String),
    /// The button came up while the drag was live; finish and commit it.
    Released(String),
}

/// Handles all engine input callbacks (mouse, keyboard, text) for the panel.
/// Owns the drag state machine and the shared event queues.
pub(crate) struct PanelInput {
    drag: DragState,
    mouse_captured: bool,
    last_mouse_x: f32,
    last_mouse_y: f32,
    cursor_x: f32,
    changes: ChangeQueue,
    interactions: InteractionQueue,
}

impl PanelInput {
    pub(crate) fn new(changes: ChangeQueue, interactions: InteractionQueue) -> Self {
        PanelInput {
            drag: DragState::Idle,
            mouse_captured: false,
            last_mouse_x: 0.0,
            last_mouse_y: 0.0,
            cursor_x: 0.0,
            changes,
            interactions,
        }
    }

    /// Forget in-flight input. The elements a drag or a queued event referred
    /// to are gone once RmlUi has been torn down and rebuilt.
    pub(crate) fn reset(&mut self) {
        self.drag = DragState::Idle;
        self.mouse_captured = false;
        self.changes.borrow_mut().clear();
        self.interactions.borrow_mut().clear();
    }

    pub(crate) fn changes(&self) -> &ChangeQueue {
        &self.changes
    }
    pub(crate) fn interactions(&self) -> &InteractionQueue {
        &self.interactions
    }

    // ── Per-tick processing (called from manager) ──────────────────

    /// Step an in-progress drag from the polled cursor position.
    ///
    /// The engine feeds mouse input straight to its RmlUi contexts, so a plugin
    /// never sees `mouse_move` while RmlUi holds the press. Lua's RmlUi fields
    /// have the same problem and solve it the same way: take the pressed state
    /// from RmlUi's mousedown/mouseup, and the position from the engine.
    /// Step an in-progress drag from the polled cursor position.
    ///
    /// Returns what happened, so the manager can capture the pre-drag value on
    /// `Started` and preview the new one on `Moved`.
    pub(crate) fn tick_drag(
        &mut self,
        interface: &NativeInterfaceRef,
        editor: Option<&mut (dyn Editor + '_)>,
    ) -> DragTick {
        let Ok(mouse) = interface.input().get_mouse_state() else {
            return DragTick::Idle;
        };
        let x = mouse.x;

        // A drag is *not* ended from `mouse.left`. The panel consumes the press,
        // so the engine never registers the button as held and `left` reads
        // false for the whole drag -- ending it here killed the drag on the tick
        // it started, before it could move.
        //
        // The release arrives either as RmlUi's `mouseup` on the field, or (when
        // the cursor left the field) as the engine's mouse-release callback,
        // which the manager turns into `force_drag_release`.
        if let DragState::Pending { field, start_x } = &self.drag {
            if (x - *start_x).abs() > DRAG_THRESHOLD {
                let field = field.clone();
                self.last_mouse_x = *start_x;
                self.drag = DragState::Dragging {
                    field: field.clone(),
                };
                // Report the start before moving: the manager has to record the
                // value the drag began from, so undo can return to it.
                return DragTick::Started(field);
            }
        }

        let DragState::Dragging { field } = &self.drag else {
            return DragTick::Idle;
        };
        let dx = x - self.last_mouse_x;
        if dx == 0.0 {
            return DragTick::Idle;
        }
        self.last_mouse_x = x;
        let mult = if self.fine_drag_multiplier(interface) {
            FINE_DRAG_MULT
        } else {
            1.0
        };
        let field = field.clone();
        let Some(ed) = editor else {
            return DragTick::Idle;
        };
        if ed.drag_field(&field, dx * mult, interface) {
            DragTick::Moved(field)
        } else {
            DragTick::Idle
        }
    }

    /// Drain interaction events and update drag state. Returns actions to
    /// execute on the editor (drag-end or click-to-edit).
    /// Cache the cursor position each tick; a press event carries no coordinates.
    pub(crate) fn set_cursor(&mut self, interface: &NativeInterfaceRef) {
        if let Ok(mouse) = interface.input().get_mouse_state() {
            self.cursor_x = mouse.x;
        }
    }

    pub(crate) fn process_interactions(&mut self) -> Vec<PendingAction> {
        let events: Vec<InteractionEvent> = self.interactions.borrow_mut().drain(..).collect();
        let mut actions = Vec::new();
        for event in events {
            match event {
                InteractionEvent::PointerDown { field } => {
                    self.drag = DragState::Pending {
                        field,
                        start_x: self.cursor_x,
                    };
                    self.last_mouse_x = self.cursor_x;
                }
                InteractionEvent::PointerUp { field } => {
                    // A drag ends wherever the button comes up. The cursor has
                    // usually left the field by then, so the `mouseup` RmlUi
                    // delivers names a *different* element -- requiring it to
                    // match the dragged field left the drag stuck, and never
                    // committed.
                    let dragged = match std::mem::replace(&mut self.drag, DragState::Idle) {
                        DragState::Dragging { field } => Some(field),
                        DragState::Pending { field: pending, .. } if pending == field => {
                            // Never crossed the threshold: it was a click.
                            actions.push(PendingAction::ClickEdit(pending));
                            None
                        }
                        _ => None,
                    };
                    if let Some(dragged) = dragged {
                        actions.push(PendingAction::DragEnd(dragged));
                    }
                }
            }
        }
        actions
    }

    /// Drain commit requests.
    pub(crate) fn drain_changes(&mut self) -> Vec<CommitRequest> {
        self.changes.borrow_mut().drain(..).collect()
    }

    /// End an active drag from the engine mouse-release callback. RmlUi only
    /// sends the field's `mouseup` when the pointer is still over that element;
    /// releasing outside must still finish the drag.
    pub(crate) fn force_drag_release(&mut self) -> Option<String> {
        let field = match &self.drag {
            DragState::Dragging { field } => Some(field.clone()),
            DragState::Pending { .. } | DragState::Idle => None,
        };
        self.drag = DragState::Idle;
        field
    }

    fn drag_field(&self) -> Option<&str> {
        match &self.drag {
            DragState::Pending { field, .. } | DragState::Dragging { field } => Some(field),
            DragState::Idle => None,
        }
    }

    // ── Input callbacks ────────────────────────────────────────────

    /// The engine's mouse-move callback. It does **not** touch the drag: a drag
    /// is stepped from the polled cursor in `tick_drag`, which owns
    /// `last_mouse_x` as the point the delta is measured from.
    ///
    /// This used to keep a second copy of the drag state machine here, and set
    /// `last_mouse_x = x` on every callback. That reset the reference point to
    /// wherever the cursor already was, so `tick_drag` always measured a delta of
    /// zero and a dragged number never moved.
    pub(crate) fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        self.last_mouse_y = y as f32;

        // A drag owns the cursor: swallow the move so RmlUi does not also act on
        // it (hovering another field, starting a text selection).
        if !matches!(self.drag, DragState::Idle) {
            return Ok(true);
        }

        self.forward_mouse_move(interface, view, x, y)
    }

    fn fine_drag_multiplier(&self, interface: &NativeInterfaceRef) -> bool {
        interface
            .input()
            .get_mod_key_state()
            .map(|s| s & SHIFT_BIT != 0)
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

    pub(crate) fn key_press(
        &self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        key_code: i32,
    ) -> Result<bool, Error> {
        if let Some(ctx) = view.context_handle() {
            return interface
                .rml_ui()
                .context_process_key_down(ctx, key_code, 0);
        }
        Ok(false)
    }

    pub(crate) fn key_release(
        &self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        key_code: i32,
    ) -> Result<bool, Error> {
        if let Some(ctx) = view.context_handle() {
            return interface.rml_ui().context_process_key_up(ctx, key_code, 0);
        }
        Ok(false)
    }

    pub(crate) fn text_input(
        &self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        utf8: &str,
    ) -> Result<bool, Error> {
        if let Some(ctx) = view.context_handle() {
            return interface.rml_ui().context_process_text_input(ctx, utf8);
        }
        Ok(false)
    }
}
