//! A generalized file/directory browser modal, a port of the file-picker windows
//! the toolbar actions open (`RmlUiSaveWindow`, load/import/export dialogs).
//!
//! It reuses the asset picker's grid + navigation, and adds what the project
//! actions need: an optional name text input (Save As, Export), an optional
//! file-type dropdown (Import's Diffuse/Heightmap, Export's five formats), and a
//! "directories are selectable" mode (Load/Save browse `.sdd` project folders).

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::actions::{FileDialogConfig, FileDialogResult};
use crate::sbc::panels::asset_picker::PickerEvent;
use crate::sbc::panels::field::{element_by_id, escape_rml};
use crate::sbc::panels::grid::{list_assets, parent_dir, GridView};

pub(crate) struct FileDialog {
    config: Option<FileDialogConfig>,
    dir: String,
    grid: GridView,
    events: Rc<RefCell<Vec<PickerEvent>>>,
    bound: bool,
}

impl Default for FileDialog {
    fn default() -> Self {
        FileDialog {
            config: None,
            dir: String::new(),
            grid: GridView::new("file-dialog-grid", 64),
            events: Rc::new(RefCell::new(Vec::new())),
            bound: false,
        }
    }
}

impl FileDialog {
    pub(crate) fn is_open(&self) -> bool {
        self.config.is_some()
    }

    /// The listeners were bound to elements the engine has since freed.
    pub(crate) fn forget_bindings(&mut self) {
        self.bound = false;
        self.config = None;
        self.events.borrow_mut().clear();
        self.grid.drain_clicks();
    }

    /// Static shell, injected into `#modal-root` once. The name/type rows are
    /// always present and shown or hidden per dialog, so the listeners bind once.
    pub(crate) fn markup(&self) -> String {
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
                r#"<div id="fd-name-row" class="fd-row hidden">"#,
                r#"<label class="fd-label">Name</label>"#,
                r#"<input type="text" id="fd-name" class="fd-input" value=""/></div>"#,
                r#"<div id="fd-type-row" class="fd-row hidden">"#,
                r#"<label class="fd-label">Type</label>"#,
                r#"<select id="fd-type" class="fd-input"></select></div>"#,
                r#"</div>"#,
                r#"<div class="dialog-footer">"#,
                r#"<button id="fd-ok" class="dialog-button primary">OK</button>"#,
                r#"<button id="fd-cancel" class="dialog-button">Cancel</button>"#,
                r#"</div></div></div>"#,
            ),
            grid = self.grid.container_rml(),
        )
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
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
        self.bound = true;
        Ok(())
    }

    pub(crate) fn open(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        config: FileDialogConfig,
    ) -> Result<(), Error> {
        self.dir = config.root_dir.trim_end_matches('/').to_string();
        self.grid.set_selected(None);

        let rml = interface.rml_ui();
        if let Some(e) = element_by_id(interface, document, "fd-title") {
            rml.element_set_inner_rml(e, &escape_rml(&config.title))?;
        }
        // Name input row.
        if let Some(e) = element_by_id(interface, document, "fd-name-row") {
            rml.element_set_class(e, "hidden", !config.show_name_input)?;
        }
        if let Some(e) = element_by_id(interface, document, "fd-name") {
            rml.element_set_attribute(e, "value", "")?;
        }
        // Type dropdown row.
        if let Some(e) = element_by_id(interface, document, "fd-type-row") {
            rml.element_set_class(e, "hidden", config.file_types.is_empty())?;
        }
        if !config.file_types.is_empty() {
            if let Some(e) = element_by_id(interface, document, "fd-type") {
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

    pub(crate) fn cancel_if_open(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<bool, Error> {
        if !self.is_open() {
            return Ok(false);
        }
        self.close(interface, document)?;
        Ok(true)
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
        let config = self.config.clone().expect("open");

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
                    if let Some(e) = element_by_id(interface, document, "fd-name") {
                        interface
                            .rml_ui()
                            .element_set_attribute(e, "value", &name)?;
                    }
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
                    let result = self.build_result(interface, document, &config)?;
                    self.close(interface, document)?;
                    return Ok(result);
                }
            }
        }
        Ok(None)
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
            .set_items(list_assets(interface, &self.dir, &extensions));
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
    fn build_result(
        &self,
        interface: &NativeInterfaceRef,
        document: u64,
        config: &FileDialogConfig,
    ) -> Result<Option<FileDialogResult>, Error> {
        let rml = interface.rml_ui();

        let file_type = if config.file_types.is_empty() {
            None
        } else {
            element_by_id(interface, document, "fd-type")
                .and_then(|e| rml.element_get_value(e).ok().flatten())
                .or_else(|| config.file_types.first().cloned())
        };

        let typed = if config.show_name_input {
            element_by_id(interface, document, "fd-name")
                .and_then(|e| rml.element_get_value(e).ok().flatten())
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
            return Ok(None);
        };

        Ok(Some(FileDialogResult { path, file_type }))
    }
}
