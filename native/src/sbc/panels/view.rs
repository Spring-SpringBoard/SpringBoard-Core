use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataNotificationRows, RmlDataTextRows, RmlDataVariable, RmlPixels,
};

use crate::sbc::actions::Action;
use crate::sbc::panels::action_bar::ActionBar;
use crate::sbc::panels::cursor::cursortip::CursorTipBindings;
use crate::sbc::panels::editor_buttons::EditorButtons;
use crate::sbc::panels::field::element_by_id;
use crate::sbc::panels::registry::Tab;
use crate::sbc::panels::tab_bar::TabBar;
use crate::sbc::panels::tooltip::PanelTooltip;
use crate::sbc::rml;

const UI_CONTEXT: &str = "sbc_native_ui";
const UI_BODY: &str = include_str!("ui.rml");
/// The stylesheet, assembled from the theme parts in cascade order. RmlUi
/// still sees one sheet; the split is source-level, by component.
const UI_STYLE: &str = concat!(
    include_str!("../theme/base.rcss"),
    include_str!("../theme/controls.rcss"),
    include_str!("../theme/scrollbars.rcss"),
    include_str!("../theme/panel/foundation.rcss"),
    include_str!("../theme/panel/shell.rcss"),
    include_str!("../theme/panel/asset_grid.rcss"),
    include_str!("../theme/panel/fields.rcss"),
    include_str!("../theme/panel/action_controls.rcss"),
    include_str!("../theme/panel/modals.rcss"),
    include_str!("../theme/panel/asset_picker.rcss"),
    include_str!("../theme/panel/notifications.rcss"),
    include_str!("../theme/panel/project_status.rcss"),
);

/// A shell-level click, queued by an RmlUi event listener and drained by the
/// manager on the next tick. Rebuilding the DOM inside a listener would free the
/// elements RmlUi is still dispatching to.
#[derive(Debug, Clone)]
pub(crate) enum ShellEvent {
    Tab(Tab),
    Editor(&'static str),
    Action(Action),
}

pub(crate) type ShellQueue = Rc<RefCell<Vec<ShellEvent>>>;

/// Owns the RmlUi context, document and shell chrome (tab bar, editor button
/// strip, content host) of the native right-hand panel.
pub(crate) struct PanelView {
    context: Option<u64>,
    document: Option<u64>,
    root: Option<u64>,
    content: Option<u64>,
    project_status_caption: Option<RmlDataVariable<'static, String>>,
    project_open_disabled: Option<RmlDataVariable<'static, bool>>,
    notification_rows: Option<RmlDataNotificationRows<'static>>,
    tooltip: Option<PanelTooltip>,
    cursor_tip_title: Option<RmlDataVariable<'static, String>>,
    cursor_tip_rows: Option<RmlDataTextRows<'static>>,
    cursor_tip_hidden: Option<RmlDataVariable<'static, bool>>,
    cursor_tip_left: Option<RmlDataVariable<'static, RmlPixels>>,
    cursor_tip_top: Option<RmlDataVariable<'static, RmlPixels>>,
    action_bar: ActionBar,
    editor_buttons: EditorButtons,
    tab_bar: TabBar,
    events: ShellQueue,
    current_tab: Tab,
    active_editor: Option<&'static str>,
}

impl Default for PanelView {
    fn default() -> Self {
        PanelView {
            context: None,
            document: None,
            root: None,
            content: None,
            project_status_caption: None,
            project_open_disabled: None,
            notification_rows: None,
            tooltip: None,
            cursor_tip_title: None,
            cursor_tip_rows: None,
            cursor_tip_hidden: None,
            cursor_tip_left: None,
            cursor_tip_top: None,
            action_bar: ActionBar::default(),
            editor_buttons: EditorButtons::default(),
            tab_bar: TabBar::default(),
            events: Rc::new(RefCell::new(Vec::new())),
            current_tab: Tab::Objects,
            active_editor: None,
        }
    }
}

impl PanelView {
    pub(crate) fn is_ready(&self) -> bool {
        self.context.is_some() && self.document.is_some()
    }

    pub(crate) fn active_editor(&self) -> Option<&'static str> {
        self.active_editor
    }

    /// The selected top-level tab. Shell clicks use this to make tab selection
    /// choice-only: selecting the current tab must not close its editor.
    pub(crate) fn current_tab(&self) -> Tab {
        self.current_tab
    }

    pub(crate) fn drain_events(&self) -> Vec<ShellEvent> {
        self.events.borrow_mut().drain(..).collect()
    }

    /// Queue what a click on the shell would have queued. The control channel
    /// enters here so an opened editor takes the same path as a clicked one.
    pub(crate) fn queue_event(&self, event: ShellEvent) {
        self.events.borrow_mut().push(event);
    }

    /// Create the context + document if the engine is ready. Returns `true` if
    /// newly created -- including a re-creation after RmlUi was torn down.
    pub(crate) fn ensure(&mut self, interface: &NativeInterfaceRef) -> Result<bool, Error> {
        if self.is_ready() {
            if self.context_is_alive(interface) {
                return Ok(false);
            }
            self.forget();
        }
        let rml = interface.rml_ui();
        if !rml.is_ready()? {
            return Ok(false);
        }

        let (ctx, ok) = rml.create_context(UI_CONTEXT)?;
        if !ok {
            return Ok(false);
        }
        let geom = interface.display().get_view_geometry()?;
        let _ = rml.context_set_dimensions(ctx, geom.viewSizeX, geom.viewSizeY);

        // The panel shell is parsed after this native model exists, so its
        // status caption stays a typed RmlUi field instead of reconstructed
        // markup on every project-state change.
        let data_model = rml.create_data_model(ctx, "panel_shell")?;
        self.project_status_caption =
            Some(data_model.bind("project_status_caption", String::new())?);
        self.project_open_disabled = Some(data_model.bind("project_open_disabled", true)?);
        self.notification_rows = Some(data_model.bind_notification_rows("notifications")?);
        let tooltip_model = rml.create_data_model(ctx, "panel_tooltip")?;
        self.tooltip = Some(PanelTooltip::bind(&tooltip_model)?);
        let cursor_tip_model = rml.create_data_model(ctx, "cursor_tip")?;
        self.cursor_tip_title = Some(cursor_tip_model.bind("title", String::new())?);
        self.cursor_tip_rows = Some(cursor_tip_model.bind_text_rows("rows")?);
        self.cursor_tip_hidden = Some(cursor_tip_model.bind("hidden", true)?);
        self.cursor_tip_left = Some(cursor_tip_model.bind("left", RmlPixels(0.0))?);
        self.cursor_tip_top = Some(cursor_tip_model.bind("top", RmlPixels(0.0))?);

        let (doc, ok) = rml.context_create_document(ctx, "body")?;
        if !ok {
            self.project_status_caption = None;
            self.project_open_disabled = None;
            self.notification_rows = None;
            self.tooltip = None;
            self.cursor_tip_title = None;
            self.cursor_tip_rows = None;
            self.cursor_tip_hidden = None;
            self.cursor_tip_left = None;
            self.cursor_tip_top = None;
            return Ok(false);
        }
        rml.document_set_title(doc, "SpringBoard")?;
        rml.document_append_to_style_sheet(doc, UI_STYLE)?;
        rml.element_set_inner_rml(doc, UI_BODY)?;
        rml.document_show(doc, None, None)?;
        // RmlUi must receive mouse events, but it must not replace the editor
        // cursor while hovering a button (its `pointer` alias used to select
        // Spring's animated Move command cursor).
        let _ = rml.context_enable_mouse_cursor(ctx, false);
        let _ = rml.context_pull_document_to_front(ctx, doc);

        self.context = Some(ctx);
        self.document = Some(doc);
        self.root = element_by_id(interface, doc, "native-panel");
        self.content = element_by_id(interface, doc, "main-content");

        self.tab_bar
            .render(interface, doc, self.current_tab, &self.events)?;
        self.action_bar.bind(
            interface,
            doc,
            self.tooltip.as_ref().expect("panel tooltip is bound"),
            &self.events,
        )?;
        self.render_editor_buttons(interface)?;
        Ok(true)
    }

    pub(crate) fn project_status_caption(&self) -> Option<&RmlDataVariable<'static, String>> {
        self.project_status_caption.as_ref()
    }

    pub(crate) fn project_open_disabled(&self) -> Option<&RmlDataVariable<'static, bool>> {
        self.project_open_disabled.as_ref()
    }

    pub(crate) fn notification_rows(&self) -> Option<&RmlDataNotificationRows<'static>> {
        self.notification_rows.as_ref()
    }

    pub(crate) fn tooltip(&self) -> Option<&PanelTooltip> {
        self.tooltip.as_ref()
    }

    pub(crate) fn cursor_tip_bindings(&self) -> Option<CursorTipBindings<'_>> {
        Some(CursorTipBindings {
            title: self.cursor_tip_title.as_ref()?,
            rows: self.cursor_tip_rows.as_ref()?,
            hidden: self.cursor_tip_hidden.as_ref()?,
            left: self.cursor_tip_left.as_ref()?,
            top: self.cursor_tip_top.as_ref()?,
        })
    }

    /// Insert static modal shells after their data models have been bound. The
    /// stack owns the actual dialogs; this view only owns their document host.
    pub(crate) fn mount_modals(
        &self,
        interface: &NativeInterfaceRef,
        markup: &str,
    ) -> Result<(), Error> {
        let Some(document) = self.document else {
            return Ok(());
        };
        if let Some(modal_root) = element_by_id(interface, document, "modal-root") {
            interface
                .rml_ui()
                .element_set_inner_rml(modal_root, markup)?;
        }
        Ok(())
    }

    /// Switch tab: restyle the tab buttons, rebuild the strip, clear content.
    /// Matches Chili, where changing tabs closes the open editor.
    pub(crate) fn set_tab(
        &mut self,
        interface: &NativeInterfaceRef,
        tab: Tab,
    ) -> Result<(), Error> {
        if self.current_tab == tab {
            return Ok(());
        }
        let Some(doc) = self.document else {
            return Ok(());
        };
        self.current_tab = tab;
        self.active_editor = None;

        self.tab_bar
            .render(interface, doc, self.current_tab, &self.events)?;
        self.render_editor_buttons(interface)?;
        self.clear_content(interface)
    }

    pub(crate) fn set_active_editor(
        &mut self,
        interface: &NativeInterfaceRef,
        name: Option<&'static str>,
    ) -> Result<(), Error> {
        self.active_editor = name;
        self.render_editor_buttons(interface)
    }

    pub(crate) fn clear_content(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(content) = self.content {
            interface.rml_ui().element_set_inner_rml(content, "")?;
        }
        Ok(())
    }

    // ── Lifecycle ──────────────────────────────────────────────────

    pub(crate) fn update(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        if let Some(ctx) = self.context {
            let geom = interface.display().get_view_geometry()?;
            let _ = interface
                .rml_ui()
                .context_set_dimensions(ctx, geom.viewSizeX, geom.viewSizeY);
            interface.rml_ui().context_update(ctx)?;
        }
        Ok(())
    }

    /// The engine renders every RmlUi context in RmlGui::RenderFrame, between
    /// BeginFrame and PresentFrame. Calling context_render here would submit
    /// geometry outside that frame, where it is dropped.
    pub(crate) fn draw(&mut self, _interface: &NativeInterfaceRef) -> Result<(), Error> {
        Ok(())
    }

    pub(crate) fn dispose(&mut self, interface: &NativeInterfaceRef) {
        if !self.context_is_alive(interface) {
            self.forget();
            return;
        }
        let rml = interface.rml_ui();
        if let Some(doc) = self.document.take() {
            let _ = rml.document_close(doc);
        }
        if let Some(ctx) = self.context.take() {
            let _ = rml.remove_context(ctx);
        }
        self.root = None;
        self.content = None;
        self.project_status_caption = None;
        self.project_open_disabled = None;
        self.notification_rows = None;
        self.tooltip = None;
        self.cursor_tip_title = None;
        self.cursor_tip_rows = None;
        self.cursor_tip_hidden = None;
        self.cursor_tip_left = None;
        self.cursor_tip_top = None;
    }

    pub(crate) fn contains(&self, interface: &NativeInterfaceRef, x: i32, y: i32) -> bool {
        self.root
            .and_then(|r| {
                interface
                    .rml_ui()
                    .element_is_point_within_element(r, x as f32, y as f32)
                    .ok()
            })
            .unwrap_or(false)
    }

    /// Modals live alongside `native-panel` so they can cover the map while a
    /// picker is open. They still share this RmlUi context, so input must be
    /// forwarded to the context when the pointer is over one of them.
    pub(crate) fn contains_modal(&self, interface: &NativeInterfaceRef, x: i32, y: i32) -> bool {
        let Some(document) = self.document else {
            return false;
        };
        [
            "color-picker",
            "asset-picker",
            "file-dialog",
            "new-project",
            "texture-material-dialog",
            "shading-texture-dialog",
            "team-edit-dialog",
        ]
        .iter()
        .any(|id| {
            crate::sbc::panels::field::element_by_id(interface, document, id)
                .and_then(|element| {
                    interface
                        .rml_ui()
                        .element_is_point_within_element(element, x as f32, y as f32)
                        .ok()
                })
                .unwrap_or(false)
        })
    }

    pub(crate) fn context_handle(&self) -> Option<u64> {
        self.context
    }
    pub(crate) fn document_handle(&self) -> Option<u64> {
        self.document
    }
    pub(crate) fn content_handle(&self) -> Option<u64> {
        self.content
    }

    /// Synchronize the current tab's registered editor controls.
    fn render_editor_buttons(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        let Some(doc) = self.document else {
            return Ok(());
        };
        self.editor_buttons.render(
            interface,
            doc,
            self.current_tab,
            self.active_editor,
            self.tooltip.as_ref().expect("panel tooltip is bound"),
            &self.events,
        )
    }

    fn context_is_alive(&self, interface: &NativeInterfaceRef) -> bool {
        rml::context_is_alive(interface, UI_CONTEXT, self.context)
    }

    /// Drop the handles without touching them: the engine already freed them.
    fn forget(&mut self) {
        self.context = None;
        self.document = None;
        self.root = None;
        self.content = None;
        self.project_status_caption = None;
        self.project_open_disabled = None;
        self.notification_rows = None;
        self.tooltip = None;
        self.cursor_tip_title = None;
        self.cursor_tip_rows = None;
        self.cursor_tip_hidden = None;
        self.cursor_tip_left = None;
        self.cursor_tip_top = None;
        self.action_bar.forget();
        self.editor_buttons.forget();
        self.tab_bar.forget();
        self.events.borrow_mut().clear();
    }
}
