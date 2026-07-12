use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::{ChangeQueue, CommitRequest, InteractionEvent, InteractionQueue};
use crate::sbc::panels::view::PanelView;

const FINE_DRAG_MULT: f32 = 0.1;
/// Mask bit for Shift in `get_mod_key_state`.
const SHIFT_BIT: u32 = 1;

/// Which field the pointer is on, and whether RmlUi has called it a drag yet.
enum DragState {
    Idle,
    /// Pressed. Becomes a drag if RmlUi says so, a click if it does not.
    Pending { field: String },
    /// RmlUi is dragging: the value follows the cursor until `dragend`.
    Dragging { field: String },
}

/// Action to perform after processing interaction events.
pub(crate) enum PendingAction {
    DragStart(String),
    DragEnd(String),
    ClickEdit(String),
}

/// What one `tick_drag` did.
pub(crate) enum DragTick {
    Idle,
    /// The field's value moved and should be previewed.
    Moved(String),
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

        // Starting and ending a drag is RmlUi's business (`dragstart`/`dragend`,
        // see `on_pointer`); this only moves the value while one is live.
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

    /// Turn the field's pointer events into drag/click actions.
    ///
    /// RmlUi decides what is a drag: it captures the pointer on `dragstart` and
    /// delivers `dragend` wherever the button is released, even off the panel.
    /// A press that never became a drag is a click, and opens the inline editor.
    pub(crate) fn process_interactions(&mut self) -> Vec<PendingAction> {
        let events: Vec<InteractionEvent> = self.interactions.borrow_mut().drain(..).collect();
        let mut actions = Vec::new();
        for event in events {
            match event {
                InteractionEvent::PointerDown { field } => {
                    self.drag = DragState::Pending { field };
                    self.last_mouse_x = self.cursor_x;
                }
                InteractionEvent::DragStart { field } => {
                    self.last_mouse_x = self.cursor_x;
                    self.drag = DragState::Dragging {
                        field: field.clone(),
                    };
                    // The manager records the value the drag began from, so undo
                    // can return to it.
                    actions.push(PendingAction::DragStart(field));
                }
                InteractionEvent::DragEnd { field } => {
                    self.drag = DragState::Idle;
                    actions.push(PendingAction::DragEnd(field));
                }
                InteractionEvent::PointerUp { field } => {
                    // Only a press that never became a drag is a click. RmlUi
                    // sends `mouseup` after `dragend` too, and that must not
                    // reopen the editor on the field just dragged.
                    if let DragState::Pending { field: pending } =
                        std::mem::replace(&mut self.drag, DragState::Idle)
                    {
                        if pending == field {
                            actions.push(PendingAction::ClickEdit(pending));
                        }
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
