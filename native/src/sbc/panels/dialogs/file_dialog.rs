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

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::actions::{FileAcceptFn, FileDialogConfig, FileDialogResult};
use crate::sbc::panels::controls::asset_picker::PickerEvent;
use crate::sbc::panels::controls::grid::{list_entries_with_dirs, parent_dir, GridView};
use crate::sbc::panels::dialogs::form::{DialogForm, FormItem};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::field::{
    element_by_id, escape_rml, ChangeQueue, FieldValue, InteractionQueue,
};
use crate::sbc::panels::fields::{ChoiceField, StringField};
use crate::sbc::panels::modal::{Modal, ModalEvent};

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
    ) -> Result<(), Error> {
        self.pending_accept = Some(on_accept);
        self.dir = config.root_dir.trim_end_matches('/').to_string();
        self.grid.set_selected(None);

        let rml = interface.rml_ui();
        if let Some(e) = element_by_id(interface, document, "fd-title") {
            rml.element_set_inner_rml(e, &escape_rml(&config.title))?;
        }
        // Name input row.
        if let Some(e) = element_by_id(interface, document, "row-fd-name") {
            rml.element_set_class(e, "hidden", !config.show_name_input)?;
        }
        self.form.set(Name, FieldValue::Text(String::new()));
        // Type dropdown row.
        if let Some(e) = element_by_id(interface, document, "row-fd-type") {
            rml.element_set_class(e, "hidden", config.file_types.is_empty())?;
        }
        if !config.file_types.is_empty() {
            if let Some(e) = element_by_id(interface, document, "field-fd-type") {
                let mut opts = String::new();
                for t in &config.file_types {
                    opts.push_str(&format!(
                        r#"<option value="{v}">{v}</option>"#,
                        v = escape_rml(t)
                    ));
                }
                rml.element_set_inner_rml(e, &opts)?;
            }
        }
        self.form.set(
            FileType,
            FieldValue::Text(config.file_types.first().cloned().unwrap_or_default()),
        );
        self.form.write(interface)?;

        self.config = Some(config);
        self.populate(interface, document)?;
        self.set_visible(interface, document, true)
    }

    pub(crate) fn close(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        self.config = None;
        self.set_visible(interface, document, false)
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
                    self.close(interface, document)?;
                    return Ok(None);
                }
                PickerEvent::Accept => {
                    self.form.commit(Name, interface);
                    self.form.commit(FileType, interface);
                    let result = self.build_result(&config);
                    self.close(interface, document)?;
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
                r#"<div id="file-dialog" class="picker-backdrop hidden">"#,
                r#"<div class="dialog picker-dialog asset-dialog">"#,
                r#"<div class="dialog-header"><span id="fd-title" class="dialog-title">File</span></div>"#,
                r#"<div class="dialog-content">"#,
                r#"<div class="asset-path-nav">"#,
                r#"<button id="fd-up" class="dialog-button">Up</button>"#,
                r#"<span id="fd-path" class="asset-path"></span></div>"#,
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

    fn set_visible(
        &self,
        interface: &NativeInterfaceRef,
        document: u64,
        visible: bool,
    ) -> Result<(), Error> {
        if let Some(e) = element_by_id(interface, document, "file-dialog") {
            interface
                .rml_ui()
                .element_set_class(e, "hidden", !visible)?;
        }
        Ok(())
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
        if let Some(e) = element_by_id(interface, document, "fd-path") {
            interface
                .rml_ui()
                .element_set_inner_rml(e, &escape_rml(&self.dir))?;
        }
        Ok(())
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
        } else if let Some(selected) = self.grid.selected() {
            selected.to_string()
        } else {
            return None;
        };

        Some(FileDialogResult { path, file_type })
    }
}

impl Modal for FileDialog {
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
    }

    fn is_open(&self) -> bool {
        self.config.is_some()
    }

    fn cancel_if_open(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<bool, Error> {
        if !self.is_open() {
            return Ok(false);
        }
        self.close(interface, document)?;
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
                Box::new(ChoiceField::new("fd-type", "Type", Vec::new())),
            ),
        ],
        vec![
            FormItem::IdentifiedField(Name),
            FormItem::IdentifiedField(FileType),
        ],
    )
}

fn text_value(value: FieldValue) -> Option<String> {
    match value {
        FieldValue::Text(value) => Some(value),
        _ => None,
    }
}
