//! A generalized file/directory browser modal, a port of the file-picker windows
//! the toolbar actions open (`RmlUiSaveWindow`, load/import/export dialogs).
//!
//! It reuses the asset picker's grid + navigation, and adds what the project
//! actions need: an optional name text input (Save As, Export), an optional
//! file-type dropdown (Import's Diffuse/Heightmap, Export's five formats), and a
//! "directories are selectable" mode (Load/Save browse `.sdd` project folders).

use std::any::Any;
use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataOptionRows, RmlDataVariable, RmlOptionRow,
};

use crate::sbc::actions::{FileAcceptFn, FileDialogConfig, FileDialogResult};
use crate::sbc::panels::controls::asset_picker::PickerEvent;
use crate::sbc::panels::controls::grid::{list_entries_with_dirs, parent_dir, GridView};
use crate::sbc::panels::dialogs::form::{DialogForm, FormItem};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::{element_by_id, ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{ChoiceField, StringField};
use crate::sbc::panels::modal::{Modal, ModalEvent};
use crate::sbc::panels::tooltip::PanelTooltip;

inventory::submit! {
    crate::sbc::panels::modal::ModalRegistration {
        order: 2,
        make: || Box::new(FileDialog::default()),
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum FileField {
    Name,
    FileType,
}

use FileField::*;

pub(crate) struct FileDialog {
    config: Option<FileDialogConfig>,
    dir: String,
    grid: GridView,
    form: DialogForm<FileField>,
    events: Rc<RefCell<Vec<PickerEvent>>>,
    bound: bool,
    title: Option<RmlDataVariable<'static, String>>,
    path: Option<RmlDataVariable<'static, String>>,
    hidden: Option<RmlDataVariable<'static, bool>>,
    show_name_input: Option<RmlDataVariable<'static, bool>>,
    show_file_type: Option<RmlDataVariable<'static, bool>>,
    file_type_options: Option<RmlDataOptionRows<'static>>,
    /// The callback the open dialog runs against its accepted result, set by the
    /// toolbar action that opened it.
    pending_accept: Option<FileAcceptFn>,
}

impl Default for FileDialog {
    fn default() -> Self {
        FileDialog {
            config: None,
            dir: String::new(),
            grid: GridView::new("file-dialog-grid", 64),
            form: file_form(),
            events: Rc::new(RefCell::new(Vec::new())),
            bound: false,
            title: None,
            path: None,
            hidden: None,
            show_name_input: None,
            show_file_type: None,
            file_type_options: None,
            pending_accept: None,
        }
    }
}

impl FileDialog {
    pub(crate) fn open(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        config: FileDialogConfig,
        on_accept: FileAcceptFn,
        tooltip: PanelTooltip,
    ) -> Result<(), Error> {
        self.grid.set_tooltip_host(tooltip);
        self.pending_accept = Some(on_accept);
        self.dir = config.root_dir.trim_end_matches('/').to_string();
        self.grid.set_selected(None);

        self.title
            .as_ref()
            .expect("file dialog title is bound before modal markup")
            .set(config.title.clone())?;
        self.show_name_input
            .as_ref()
            .expect("file-dialog name visibility is bound before modal markup")
            .set(config.show_name_input)?;
        self.form.set(Name, FieldValue::Text(String::new()));
        self.show_file_type
            .as_ref()
            .expect("file-dialog type visibility is bound before modal markup")
            .set(!config.file_types.is_empty())?;
        self.write_file_type_options(&config.file_types)?;
        self.form.set(
            FileType,
            FieldValue::Text(config.file_types.first().cloned().unwrap_or_default()),
        );
        self.form.write(interface)?;

        self.config = Some(config);
        self.populate(interface, document)?;
        self.set_visible(true)
    }

    pub(crate) fn close(&mut self) -> Result<(), Error> {
        self.config = None;
        self.set_visible(false)
    }

    /// Handle queued clicks and buttons; returns a result on OK.
    pub(crate) fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Option<FileDialogResult>, Error> {
        if !self.is_open() {
            self.grid.drain_clicks();
            self.events.borrow_mut().clear();
            return Ok(None);
        }
        let Some(config) = self.config.clone() else {
            return Ok(None);
        };

        for id in self.grid.drain_clicks() {
            let item_is_dir = self.grid.item(&id).is_some_and(|i| i.is_directory);
            let selectable = !item_is_dir || self.dir_is_item(&config, &id);
            if selectable {
                self.grid.set_selected(Some(&id));
                // Selecting a directory as an item pre-fills the name field.
                if item_is_dir && config.show_name_input {
                    let name = id
                        .rsplit('/')
                        .next()
                        .unwrap_or(&id)
                        .trim_end_matches(".sdd")
                        .to_string();
                    self.form.set(Name, FieldValue::Text(name));
                    self.form.write(interface)?;
                }
                self.grid.render(interface, document)?;
            } else {
                self.dir = id;
                self.grid.set_selected(None);
                self.populate(interface, document)?;
            }
        }

        let events: Vec<PickerEvent> = self.events.borrow_mut().drain(..).collect();
        for event in events {
            match event {
                PickerEvent::Up => {
                    let root = config.root_dir.trim_end_matches('/');
                    if self.dir != root {
                        if let Some(parent) = parent_dir(&self.dir) {
                            self.dir = parent;
                            self.grid.set_selected(None);
                            self.populate(interface, document)?;
                        }
                    }
                }
                PickerEvent::Cancel => {
                    self.close()?;
                    return Ok(None);
                }
                PickerEvent::Accept => {
                    self.form.commit(Name, interface);
                    self.form.commit(FileType, interface);
                    let result = self.build_result(&config);
                    self.close()?;
                    return Ok(result);
                }
            }
        }
        Ok(None)
    }

    /// Static shell, injected into `#modal-root` once. The name/type rows are
    /// always present and shown or hidden per dialog, so the listeners bind once.
    fn markup_rml(&self) -> String {
        format!(
            concat!(
                r#"<div id="file-dialog" class="picker-backdrop" data-model="file_dialog" data-class-hidden="hidden">"#,
                r#"<div class="dialog picker-dialog asset-dialog">"#,
                r#"<div class="dialog-header"><span class="dialog-title">{{{{ title }}}}</span></div>"#,
                r#"<div class="dialog-content">"#,
                r#"<div class="asset-path-nav">"#,
                r#"<button id="fd-up" class="dialog-button">Up</button>"#,
                r#"<span class="asset-path">{{{{ path }}}}</span></div>"#,
                r#"{grid}"#,
                r#"{form}"#,
                r#"</div>"#,
                r#"<div class="dialog-footer">"#,
                r#"<button id="fd-ok" class="dialog-button primary">OK</button>"#,
                r#"<button id="fd-cancel" class="dialog-button">Cancel</button>"#,
                r#"</div></div></div>"#,
            ),
            grid = self.grid.container_rml(),
            form = self.form.markup(),
        )
    }

    fn bind_listeners(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        if self.bound {
            return Ok(());
        }
        let rml = interface.rml_ui();
        for (id, event) in [
            ("fd-ok", PickerEvent::Accept),
            ("fd-cancel", PickerEvent::Cancel),
            ("fd-up", PickerEvent::Up),
        ] {
            let Some(e) = element_by_id(interface, document, id) else {
                continue;
            };
            let q = self.events.clone();
            rml.element_add_event_listener(e, "click", false, move || {
                q.borrow_mut().push(event);
            })?;
        }
        self.form.bind(interface, document, changes, interactions)?;
        self.bound = true;
        Ok(())
    }

    fn set_visible(&self, visible: bool) -> Result<(), Error> {
        self.hidden
            .as_ref()
            .expect("file-dialog visibility is bound before modal markup")
            .set(!visible)
    }

    fn populate(&mut self, interface: &NativeInterfaceRef, document: u64) -> Result<(), Error> {
        let extensions: Vec<&str> = self
            .config
            .as_ref()
            .map(|c| c.extensions.iter().map(String::as_str).collect())
            .unwrap_or_default();
        self.grid
            .set_items(list_entries_with_dirs(interface, &self.dir, &extensions));
        self.grid.render(interface, document)?;
        self.path
            .as_ref()
            .expect("file dialog path is bound before modal markup")
            .set(self.dir.clone())?;
        Ok(())
    }

    fn write_file_type_options(&mut self, file_types: &[String]) -> Result<(), Error> {
        let options = file_types
            .iter()
            .map(|file_type| RmlOptionRow {
                value: file_type.clone(),
                label: file_type.clone(),
            })
            .collect::<Vec<_>>();
        self.file_type_options
            .as_ref()
            .expect("file dialog options are bound before modal markup")
            .set(&options)
    }

    /// True when a directory is a selectable item (e.g. a `.sdd` project folder)
    /// rather than something to navigate into.
    fn dir_is_item(&self, config: &FileDialogConfig, id: &str) -> bool {
        if !config.dirs_as_items {
            return false;
        }
        let name = id.rsplit('/').next().unwrap_or(id).to_lowercase();
        config.extensions.is_empty()
            || config
                .extensions
                .iter()
                .any(|ext| name.ends_with(&ext.to_lowercase()))
    }

    /// Resolve the picked path + type from the current selection, name input and
    /// type dropdown. Returns None if the dialog can't produce a path yet (no
    /// name typed and nothing selected).
    fn build_result(&self, config: &FileDialogConfig) -> Option<FileDialogResult> {
        let file_type = if config.file_types.is_empty() {
            None
        } else {
            text_value(self.form.value(FileType))
                .filter(|value| !value.is_empty())
                .or_else(|| config.file_types.first().cloned())
        };

        let typed = if config.show_name_input {
            text_value(self.form.value(Name))
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
        } else {
            None
        };

        let path = if let Some(name) = typed {
            // A typed name lands in the directory currently browsed.
            let mut path = format!("{}/{}", self.dir, name);
            if let Some(ext) = config.extensions.first() {
                if !path.to_lowercase().ends_with(&ext.to_lowercase()) {
                    path.push_str(ext);
                }
            }
            path
        } else {
            self.grid.selected()?.to_string()
        };

        Some(FileDialogResult { path, file_type })
    }
}

impl Modal for FileDialog {
    fn control_name(&self) -> Option<&'static str> {
        self.config.as_ref().map(|config| config.control_name)
    }

    fn control_field_name(&self, name: &str) -> Option<String> {
        match name {
            "name" => Some("fd-name".to_string()),
            "file_type" | "type" => Some("fd-type".to_string()),
            _ => None,
        }
    }

    fn control_select(
        &mut self,
        path: &str,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<bool, Error> {
        let Some(config) = self.config.clone() else {
            return Ok(false);
        };
        let selectable = self
            .grid
            .item(path)
            .is_some_and(|item| !item.is_directory || self.dir_is_item(&config, path));
        if !selectable {
            return Ok(false);
        }
        self.grid.set_selected(Some(path));
        self.grid.render(interface, document)?;
        Ok(true)
    }

    fn control_accept(&mut self) -> bool {
        self.events.borrow_mut().push(PickerEvent::Accept);
        true
    }

    fn control_cancel(&mut self) -> bool {
        self.events.borrow_mut().push(PickerEvent::Cancel);
        true
    }

    fn prepare_data_model(
        &mut self,
        interface: &NativeInterfaceRef,
        context: u64,
    ) -> Result<(), Error> {
        let data_model = interface
            .rml_ui()
            .create_data_model(context, "file_dialog")?;
        self.title = Some(data_model.bind("title", String::new())?);
        self.path = Some(data_model.bind("path", String::new())?);
        self.hidden = Some(data_model.bind("hidden", true)?);
        self.show_name_input = Some(data_model.bind("show_name_input", false)?);
        self.show_file_type = Some(data_model.bind("show_file_type", false)?);
        self.file_type_options = Some(data_model.bind_option_rows("types")?);
        self.form.prepare_data_model(&data_model)?;
        self.grid.prepare_data_model(&data_model)?;
        Ok(())
    }

    fn markup(&self) -> String {
        self.markup_rml()
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.bind_listeners(interface, document, changes, interactions)
    }

    fn forget_bindings(&mut self) {
        self.bound = false;
        self.config = None;
        self.pending_accept = None;
        self.events.borrow_mut().clear();
        self.grid.drain_clicks();
        self.grid.forget_bindings();
        self.title = None;
        self.path = None;
        self.hidden = None;
        self.show_name_input = None;
        self.show_file_type = None;
        self.file_type_options = None;
    }

    fn is_open(&self) -> bool {
        self.config.is_some()
    }

    fn cancel_if_open(
        &mut self,
        _interface: &NativeInterfaceRef,
        _document: u64,
    ) -> Result<bool, Error> {
        if !self.is_open() {
            return Ok(false);
        }
        self.close()?;
        self.pending_accept = None;
        Ok(true)
    }

    fn poll(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Vec<ModalEvent>, Error> {
        let mut events = Vec::new();
        if let Some(result) = self.tick(interface, document)? {
            if let Some(on_accept) = self.pending_accept.take() {
                events.push(ModalEvent::Commands(on_accept(&result, interface)));
            }
        } else if !self.is_open() {
            // The dialog closed (cancel); drop any pending callback.
            self.pending_accept = None;
        }
        Ok(events)
    }

    fn field_editor(&self) -> Option<&dyn Editor> {
        self.is_open().then(|| self.form.editor())
    }

    fn field_editor_mut(&mut self) -> Option<&mut dyn Editor> {
        self.is_open().then(|| self.form.editor_mut())
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

fn file_form() -> DialogForm<FileField> {
    DialogForm::new(
        vec![
            (Name, Box::new(StringField::new("fd-name", "Name", ""))),
            (
                FileType,
                Box::new(ChoiceField::new("fd-type", "Type", Vec::new()).with_option_rows("types")),
            ),
        ],
        vec![
            FormItem::IdentifiedFieldWhen(Name, "show_name_input"),
            FormItem::IdentifiedFieldWhen(FileType, "show_file_type"),
        ],
    )
}

fn text_value(value: FieldValue) -> Option<String> {
    match value {
        FieldValue::Text(value) => Some(value),
        _ => None,
    }
}
