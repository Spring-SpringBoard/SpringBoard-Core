use std::any::Any;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::actions::{self, Action, ActionResult};
use crate::sbc::chonsole::ChonsoleManager;
use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::history::HistoryEvent;
use crate::sbc::command_system::model::{Model, ModelFactory, Models};
use crate::sbc::notifications::NotificationManager;
use crate::sbc::panels::action_dispatcher::ActionDispatcher;
use crate::sbc::panels::brush_sync::BrushSync;
use crate::sbc::panels::controls::asset_picker::AssetPicker;
use crate::sbc::panels::controls::color_picker::ColorPicker;
use crate::sbc::panels::cursor::cursortip::CursorTip;
use crate::sbc::panels::dialogs::file_dialog::FileDialog;
use crate::sbc::panels::editor_slot::EditorSlot;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::panels::field::{new_change_queue, new_interaction_queue};
use crate::sbc::panels::field_session::FieldSession;
use crate::sbc::panels::field_target::ActiveFieldEditor;
use crate::sbc::panels::input::{DragTick, PanelInput, PendingAction};
use crate::sbc::panels::modal::ModalEvent;
use crate::sbc::panels::modal_stack::ModalStack;
use crate::sbc::panels::view::{PanelView, ShellEvent};
use crate::sbc::port_flags::{self, UiImpl};
use crate::sbc::project::new_project_dialog::NewProjectDialog;
use crate::sbc::project::{EditorState, ProjectStatusBar};
use crate::sbc::states::{StateManager, StateRequest};

mod control;
mod input;

inventory::submit! {
    ModelFactory { make: |iface| Box::new(PanelManager::new(iface)) }
}

/// The panel's composition root: wires the view (RmlUi lifecycle + shell
/// chrome), input, the active editor slot, the field-commit session, the modal
/// stack, hotkeys, and brush sync, in a fixed per-tick order. Implements
/// `Model` so the command system can notify it of history changes (undo/redo →
/// refresh fields).
pub(crate) struct PanelManager {
    interface: NativeInterfaceRef,
    enabled: bool,
    view: PanelView,
    input: PanelInput,
    slot: EditorSlot,
    session: FieldSession,
    modals: ModalStack,
    hotkeys: ActionDispatcher,
    brush: BrushSync,
    /// The useful native replacement for the engine's "No tooltip defined" box.
    cursor_tip: CursorTip,
    /// Top-left project location + always-available launcher actions.
    status_bar: ProjectStatusBar,
    /// A field whose edit just opened: focus + select it next tick, after the
    /// RmlUi update has processed the input's unhide (same-frame focus on a
    /// just-unhidden element is rejected).
    pending_select: Option<String>,
    /// Commands produced natively (typed, no JSON envelope). Drained and
    /// submitted directly by `SBC::drain_panel_commands`.
    pending_commands: Vec<Box<dyn Command>>,
}

impl Model for PanelManager {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
    fn on_history_events(&mut self, _events: &[HistoryEvent]) {
        if self.enabled {
            self.slot.request_refresh();
        }
    }
}

impl Drop for PanelManager {
    fn drop(&mut self) {
        if self.enabled {
            self.view.dispose(&self.interface);
        }
    }
}

impl PanelManager {
    pub fn new(interface: NativeInterfaceRef) -> Self {
        let enabled = port_flags::ui_impl(&interface) == UiImpl::Rust;
        log::info!("native UI {}", if enabled { "enabled" } else { "disabled" });
        if enabled {
            match interface.unsynced_ctrl().set_draw_selection_info(false) {
                Ok(true) => {}
                Ok(false) => log::warn!("could not disable the engine selection tooltip"),
                Err(err) => log::warn!("disable engine selection tooltip: {err:?}"),
            }
        }
        PanelManager {
            interface,
            enabled,
            view: PanelView::default(),
            input: PanelInput::new(new_change_queue(), new_interaction_queue()),
            slot: EditorSlot::default(),
            session: FieldSession::default(),
            modals: ModalStack::default(),
            hotkeys: ActionDispatcher::default(),
            brush: BrushSync::default(),
            cursor_tip: CursorTip::default(),
            status_bar: ProjectStatusBar::default(),
            pending_select: None,
            pending_commands: Vec::new(),
        }
    }

    pub fn update(&mut self, models: &mut Models) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        let view_created = self.view.ensure(&self.interface)?;
        if view_created {
            // A fresh context: every element handle the editor, the pickers and
            // the input layer cached belongs to a document that no longer
            // exists. Start over rather than touch any of them.
            self.slot.close();
            self.session.reset();
            self.modals.forget_bindings();
            self.hotkeys.clear();
            self.status_bar.forget();
            self.pending_select = None;
            self.input.reset();
            let context = self
                .view
                .context_handle()
                .expect("fresh native panel has an RmlUi context");
            self.modals.prepare_data_models(&self.interface, context)?;
            self.view
                .mount_modals(&self.interface, &self.modals.markup())?;
            self.view.set_active_editor(&self.interface, None)?;
        }
        if !self.view.is_ready() {
            return Ok(());
        }
        if let Some(doc) = self.view.document_handle() {
            self.modals.bind(
                &self.interface,
                doc,
                self.input.changes(),
                self.input.interactions(),
            )?;
        }

        if let Some(field) = self.pending_select.take() {
            if self.session.editing() == Some(field.as_str()) {
                let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
                if let Some(ed) = target.get_mut() {
                    ed.select_edit_field(&field, &self.interface);
                }
            }
        }

        self.process_shell_events(models)?;
        for action in self.hotkeys.take() {
            self.run_action(action, models)?;
        }
        self.input.set_cursor(&self.interface);
        self.process_interactions()?;

        // Advance an in-progress drag from the polled cursor. Each step previews
        // on the engine, so a dragged number is visible before the mouse is
        // released; the undoable command lands on `dragend`.
        let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
        let drag_tick = self.input.tick_drag(&self.interface, target.get_mut());
        match drag_tick {
            DragTick::Moved(field) => {
                let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
                if let Some(ed) = target.get_mut() {
                    let commands = self.session.preview_field(&field, ed);
                    self.pending_commands.extend(commands);
                }
            }
            DragTick::Idle => {}
        }

        // Commit requests: a select's "change", Enter in a text field, or a
        // field losing focus. The session drops the ones that changed nothing,
        // which is what the editor's own writes echo back as.
        for request in self.input.drain_changes() {
            let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
            if request.revert {
                self.session
                    .revert_field(&request.field, target.get_mut(), &self.interface);
            } else {
                let commands = self.session.commit_field(
                    &request.field,
                    request.from_blur,
                    target.get_mut(),
                    &self.interface,
                );
                self.pending_commands.extend(commands);
            }
        }

        // Dialog accept handlers consume the values above, after the same
        // field pipeline used by the active editor has committed them.
        self.process_modals()?;

        self.slot.poll_watch(models);
        self.slot
            .maintain(&self.interface, &self.view, &self.input, models)?;

        // Editors that own more than fields (the def grids, the brush action
        // buttons) do their work here, outside the RmlUi event dispatch.
        if let (Some(doc), Some(ed)) = (self.view.document_handle(), self.slot.editor_mut()) {
            let commands = ed.tick(&self.interface, doc);
            self.pending_commands.extend(commands);
        }
        if let Some(ed) = self.slot.editor_mut() {
            self.brush.sync(ed, models, &self.interface);
        }
        self.slot.save_editor_state(models.get::<EditorState>());
        self.slot.dispatch_state_request(models);
        self.slot
            .sync_state_selection(&self.interface, &self.view, models);
        self.update_cursor_tip(models.get::<ChonsoleManager>().visible())?;
        let status_commands = self.status_bar.process(&self.interface, models);
        self.pending_commands.extend(status_commands);
        if let Some(doc) = self.view.document_handle() {
            self.status_bar.render(
                &self.interface,
                doc,
                self.view.project_status_caption(),
                self.view.project_open_disabled(),
                models,
            )?;
            let notifications_changed = models.get::<NotificationManager>().tick();
            if view_created || notifications_changed {
                models
                    .get::<NotificationManager>()
                    .render(self.view.notification_rows())?;
            }
        }
        self.view.update(&self.interface)?;
        Ok(())
    }

    pub fn draw_screen(&mut self) -> Result<(), Error> {
        if !self.enabled {
            return Ok(());
        }
        // The def grids render their thumbnails here, where the GL context is
        // current (creating and drawing to FBO textures).
        if let Some(ed) = self.slot.editor_mut() {
            ed.draw_thumbnails(&self.interface);
        }
        self.view.draw(&self.interface)
    }

    /// Called after the asynchronous editor-state reader has populated the
    /// project store. This only refreshes fields and grids; it never submits a
    /// field command or touches the undo stack.
    pub(crate) fn editor_state_loaded(&mut self, models: &mut Models) {
        self.slot.load_editor_state(models.get::<EditorState>());
    }

    /// Typed commands queued by native producers (no JSON envelope).
    pub fn drain_commands(&mut self) -> Vec<Box<dyn Command>> {
        std::mem::take(&mut self.pending_commands)
    }

    /// Run a toolbar action or hotkey. Actions either dispatch commands directly,
    /// or ask to open a dialog whose result the modal stack feeds back.
    pub(crate) fn run_action(&mut self, action: Action, models: &mut Models) -> Result<(), Error> {
        if !actions::can_execute(action, models) {
            return Ok(());
        }
        match actions::execute(action, &self.interface, models) {
            ActionResult::None => {}
            ActionResult::NativeCommands(commands) => self.pending_commands.extend(commands),
            ActionResult::OpenFileDialog { config, on_accept } => {
                if let Some(doc) = self.view.document_handle() {
                    self.modals.get_mut::<FileDialog>().open(
                        &self.interface,
                        doc,
                        config,
                        on_accept,
                        self.view.tooltip().expect("panel tooltip is bound").clone(),
                    )?;
                }
            }
            ActionResult::OpenNewProject => {
                if let Some(doc) = self.view.document_handle() {
                    self.modals
                        .get_mut::<NewProjectDialog>()
                        .open(&self.interface, doc)?;
                }
            }
        }
        // Paste needs the cursor's ground position, which the action layer can't
        // reach; run it here where the mouse state is available.
        if action == Action::Paste {
            self.run_paste(models);
        }
        Ok(())
    }

    // ── Shell ──────────────────────────────────────────────────────

    /// Tab and editor-button clicks are queued by the listeners and handled
    /// here, one tick later: rebuilding the DOM while RmlUi is dispatching the
    /// click frees the element it is dispatching to.
    fn process_shell_events(&mut self, models: &mut Models) -> Result<(), Error> {
        for event in self.view.drain_events() {
            match event {
                ShellEvent::Tab(tab) => {
                    // Tabs are choices, not toggles. In particular, do this
                    // check before resetting the editing state: resetting the
                    // state and dropping the editor while `PanelView` keeps the
                    // tab visually selected is what made a second click look
                    // like it deselected the tab.
                    if self.view.current_tab() == tab {
                        continue;
                    }
                    self.reset_state(models);
                    self.view.set_tab(&self.interface, tab)?;
                    self.slot.save_editor_state(models.get::<EditorState>());
                    self.slot.release_bindings(&self.interface)?;
                    self.slot.close();
                }
                ShellEvent::Editor(name) => {
                    // Editor buttons (Units, Features, Properties, and every
                    // other subtab) are choices too. Re-clicking one simply
                    // leaves it open and preserves its editing state.
                    if self.view.active_editor() == Some(name) {
                        continue;
                    }
                    self.reset_state(models);
                    self.slot.open(
                        name,
                        &self.interface,
                        &mut self.view,
                        models.get::<EditorState>(),
                    )?;
                }
                ShellEvent::Action(action) => self.run_action(action, models)?,
            }
        }
        Ok(())
    }

    fn reset_state(&mut self, models: &mut Models) {
        models.with::<StateManager, _>(|states, models| {
            states.set_state(StateRequest::Default, models)
        });
    }

    /// Pointer interactions: RmlUi's drag, or a click that opens the editor.
    fn process_interactions(&mut self) -> Result<(), Error> {
        for action in self.input.process_interactions(&self.interface) {
            match action {
                PendingAction::DragStart(field) => {
                    let target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
                    if let Some(ed) = target.get() {
                        self.session.begin_drag(field, ed);
                    }
                }
                PendingAction::DragEnd(field) => {
                    let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
                    if let Some(ed) = target.get_mut() {
                        ed.drag_end_field(&field, &self.interface);
                    }
                    let commands =
                        self.session
                            .commit_drag(&field, target.get_mut(), &self.interface);
                    self.pending_commands.extend(commands);
                }
                PendingAction::ClickEdit(field) => {
                    let target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
                    let asset = target.get().and_then(|editor| editor.field_asset(&field));
                    if let Some((root, extensions)) = asset {
                        if let Some(doc) = self.view.document_handle() {
                            let exts: Vec<&str> = extensions.iter().map(String::as_str).collect();
                            self.modals.get_mut::<AssetPicker>().open(
                                &self.interface,
                                doc,
                                &field,
                                &root,
                                &exts,
                                self.view.tooltip().expect("panel tooltip is bound").clone(),
                            )?;
                        }
                        continue;
                    }
                    let target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
                    let value = target.get().map(|editor| editor.field_value(&field));
                    if let Some(FieldValue::Color(rgba)) = value {
                        if let Some(doc) = self.view.document_handle() {
                            self.modals.get_mut::<ColorPicker>().open(
                                &self.interface,
                                doc,
                                &field,
                                rgba,
                            )?;
                        }
                        continue;
                    }
                    let mut target = ActiveFieldEditor::new(&mut self.modals, &mut self.slot);
                    if let Some(ed) = target.get_mut() {
                        ed.begin_edit_field(&field, &self.interface);
                    }
                    self.pending_select = Some(field.clone());
                    self.session.begin_edit(field);
                }
            }
        }
        Ok(())
    }

    /// Apply what the modal stack produced this tick.
    fn process_modals(&mut self) -> Result<(), Error> {
        let Some(doc) = self.view.document_handle() else {
            return Ok(());
        };
        for event in self.modals.poll(&self.interface, doc)? {
            match event {
                ModalEvent::FieldValue {
                    field,
                    value,
                    preview,
                } => {
                    if let Some(ed) = self.slot.editor_mut() {
                        let commands = self.session.apply_field_value(
                            &field,
                            value,
                            preview,
                            ed,
                            &self.interface,
                        );
                        self.pending_commands.extend(commands);
                    }
                }
                ModalEvent::Commands(commands) => self.pending_commands.extend(commands),
            }
        }
        Ok(())
    }

    fn close_top_modal(&mut self) -> Result<bool, Error> {
        let Some(doc) = self.view.document_handle() else {
            return Ok(false);
        };
        self.modals.close_top(&self.interface, doc)
    }

    /// Paste the clipboard at the cursor's ground hit — or, when the cursor is
    /// over the panel (the toolbar Paste icon was clicked, not Ctrl+V over the
    /// map), at the centre of the map view, so the paste always lands somewhere
    /// visible instead of off-screen.
    fn run_paste(&mut self, models: &mut Models) {
        const PANEL_WIDTH: f32 = 500.0;
        let Ok(geometry) = self.interface.display().get_view_geometry() else {
            return;
        };
        let map_width = (geometry.viewSizeX as f32 - PANEL_WIDTH).max(1.0);
        let (x, y) = match (
            self.interface.input().get_mouse_state(),
            crate::sbc::states::cursor(&self.interface),
        ) {
            // `get_mouse_state` exposes Lua's bottom-origin Y, while
            // `trace_ground` takes the top-origin coordinate expected by
            // TraceScreenRay. `states::cursor` owns that conversion for all
            // polled editor tools; Paste must use it too.
            (Ok(mouse), Some(cursor)) if mouse.x < map_width => (cursor.x, cursor.y),
            _ => (map_width / 2.0, geometry.viewSizeY as f32 / 2.0),
        };
        let Some(hit) = crate::sbc::states::trace_ground(&self.interface, x, y) else {
            return;
        };
        let commands = actions::execute_paste(&self.interface, models, hit.x, hit.z);
        self.pending_commands.extend(commands);
    }

    /// The native tooltip is shown over map objects, but never over the panel
    /// or Chonsole, which each own their own UI tooltips.
    fn update_cursor_tip(&mut self, chonsole_open: bool) -> Result<(), Error> {
        let Some(bindings) = self.view.cursor_tip_bindings() else {
            return Ok(());
        };
        const PANEL_WIDTH: f32 = 500.0;
        let over_panel = match (
            self.interface.input().get_mouse_state(),
            self.interface.display().get_view_geometry(),
        ) {
            (Ok(mouse), Ok(geometry)) => mouse.x >= geometry.viewSizeX as f32 - PANEL_WIDTH,
            _ => true,
        };
        self.cursor_tip
            .update(&self.interface, bindings, over_panel || chonsole_open)
    }
}
