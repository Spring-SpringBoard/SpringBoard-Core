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
    pub(crate) fn tick_drag(
        &mut self,
        interface: &NativeInterfaceRef,
        editor: Option<&mut (dyn Editor + '_)>,
    ) {
        let Ok(mouse) = interface.input().get_mouse_state() else {
            return;
        };
        let x = mouse.x;

        if let DragState::Pending { field, start_x } = &self.drag {
            if (x - *start_x).abs() > DRAG_THRESHOLD {
                let field = field.clone();
                self.last_mouse_x = *start_x;
                self.drag = DragState::Dragging { field };
            }
        }

        let DragState::Dragging { field } = &self.drag else {
            return;
        };
        let dx = x - self.last_mouse_x;
        if dx == 0.0 {
            return;
        }
        self.last_mouse_x = x;
        let mult = if self.fine_drag_multiplier(interface) {
            FINE_DRAG_MULT
        } else {
            1.0
        };
        if let Some(ed) = editor {
            ed.drag_field(field, dx * mult, interface);
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
                    let was_dragging = matches!(self.drag, DragState::Dragging { .. });
                    let field_matches = self.drag_field() == Some(&field);
                    self.drag = DragState::Idle;
                    if field_matches {
                        actions.push(if was_dragging {
                            PendingAction::DragEnd(field)
                        } else {
                            PendingAction::ClickEdit(field)
                        });
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

    pub(crate) fn mouse_move(
        &mut self,
        interface: &NativeInterfaceRef,
        view: &PanelView,
        editor: Option<&mut (dyn Editor + '_)>,
        x: i32,
        y: i32,
    ) -> Result<bool, Error> {
        self.last_mouse_x = x as f32;
        self.last_mouse_y = y as f32;

        // Check drag threshold transition (extract data before mutating)
        let transition = match &self.drag {
            DragState::Pending { field, start_x } => {
                let dx = x as f32 - *start_x;
                if dx.abs() > DRAG_THRESHOLD {
                    Some((field.clone(), *start_x))
                } else {
                    None
                }
            }
            _ => None,
        };
        if let Some((field, start_x)) = transition {
            self.drag = DragState::Dragging { field };
            self.last_mouse_x = start_x;
        }

        // Active drag: adjust value, consume event
        if let DragState::Dragging { ref field } = &self.drag {
            let dx = x as f32 - self.last_mouse_x;
            self.last_mouse_x = x as f32;
            let mult = if self.fine_drag_multiplier(interface) {
                FINE_DRAG_MULT
            } else {
                1.0
            };
            if let Some(ed) = editor {
                ed.drag_field(field, dx * mult, interface);
            }
            return Ok(true);
        }

        // Pending (below threshold): consume but don't adjust
        if matches!(self.drag, DragState::Pending { .. }) {
            return Ok(true);
        }

        // Normal mouse move — forward to RmlUi if inside panel
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
        let interacting = interface.rml_ui().context_is_mouse_interacting(ctx)?;
        if !inside && !interacting {
            if self.mouse_captured {
                let _ = interface.rml_ui().context_process_mouse_leave(ctx);
            }
            self.mouse_captured = false;
            return Ok(false);
        }
        interface
            .rml_ui()
            .context_process_mouse_move(ctx, x as f32, y as f32, 0)?;
        self.mouse_captured = inside || interacting;
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
        if !view.contains(interface, x, y) && !self.mouse_captured {
            return Ok(false);
        }
        interface
            .rml_ui()
            .context_process_mouse_move(ctx, x as f32, y as f32, 0)?;
        self.mouse_captured = true;
        let consumed = interface
            .rml_ui()
            .context_process_mouse_button_down(ctx, button - 1, 0)?;
        Ok(consumed || self.drag_field().is_some())
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
