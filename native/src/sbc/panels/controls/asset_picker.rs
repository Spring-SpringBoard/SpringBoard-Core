//! Asset picker modal: browse the VFS under a root directory and pick a file.
//!
//! A port of `RmlUiAssetPickerWindow`. The material and unit/feature pickers are
//! the same grid with a different item source.

use std::any::Any;
use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::controls::grid::{list_asset_tree, parent_dir, GridView};
use crate::sbc::panels::field::{
    element_by_id, escape_rml, ChangeQueue, FieldValue, InteractionQueue,
};
use crate::sbc::panels::modal::{Modal, ModalEvent};

inventory::submit! {
    crate::sbc::panels::modal::ModalRegistration {
        order: 1,
        make: || Box::new(AssetPicker::default()),
    }
}

#[derive(Debug, Clone, Copy)]
pub(crate) enum PickerEvent {
    Accept,
    Cancel,
    Up,
}

pub(crate) struct AssetPicker {
    /// The field being edited, and the root it browses.
    field: Option<String>,
    root: String,
    dir: String,
    extensions: Vec<String>,
    grid: GridView,
    events: Rc<RefCell<Vec<PickerEvent>>>,
    bound: bool,
}

impl Default for AssetPicker {
    fn default() -> Self {
        AssetPicker {
            field: None,
            root: String::new(),
            dir: String::new(),
            extensions: Vec::new(),
            grid: GridView::new("asset-grid", 64),
            events: Rc::new(RefCell::new(Vec::new())),
            bound: false,
        }
    }
}

impl AssetPicker {
    pub(crate) fn field(&self) -> Option<&str> {
        self.field.as_deref()
    }

    pub(crate) fn open(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        field: &str,
        root: &str,
        extensions: &[&str],
    ) -> Result<(), Error> {
        self.field = Some(field.to_string());
        // `root` is the field's directory *within* an asset pack
        // (`brush_textures/`), not a place on disk — except a `vfs:` root,
        // which browses that engine VFS directory itself. For packs, `core` is
        // SpringBoard's shipped/default pack, so start there instead of making
        // every picker require an extra click.
        self.root = root.to_string();
        self.dir = if root.starts_with("vfs:") {
            String::new()
        } else {
            "core/".to_string()
        };
        self.extensions = extensions.iter().map(|e| e.to_string()).collect();
        self.grid.set_selected(None);
        self.populate(interface, document)?;
        self.set_visible(interface, document, true)
    }

    pub(crate) fn close(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        self.field = None;
        self.set_visible(interface, document, false)
    }

    /// Handle queued clicks and buttons. Returns the accepted asset path.
    pub(crate) fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Option<String>, Error> {
        if !self.is_open() {
            self.grid.drain_clicks();
            self.events.borrow_mut().clear();
            return Ok(None);
        }

        // Clicking a directory navigates; clicking a file selects it.
        for id in self.grid.drain_clicks() {
            let is_dir = self.grid.item(&id).is_some_and(|i| i.is_directory);
            if is_dir {
                self.dir = id;
                self.grid.set_selected(None);
                self.populate(interface, document)?;
            } else {
                self.grid.set_selected(Some(&id));
                self.grid.render(interface, document)?;
            }
        }

        let events: Vec<PickerEvent> = self.events.borrow_mut().drain(..).collect();
        for event in events {
            match event {
                PickerEvent::Up => {
                    // Above the pack list there is nothing; `parent_dir` of a
                    // top-level pack ("core/") gives the empty string, which *is*
                    // the pack list.
                    if !self.dir.is_empty() {
                        self.dir = parent_dir(&self.dir).unwrap_or_default();
                        self.grid.set_selected(None);
                        self.populate(interface, document)?;
                    }
                }
                PickerEvent::Cancel => {
                    self.close(interface, document)?;
                    return Ok(None);
                }
                PickerEvent::Accept => {
                    let picked = self.grid.selected().map(str::to_string);
                    self.close(interface, document)?;
                    return Ok(picked);
                }
            }
        }
        Ok(None)
    }

    fn markup_rml(&self) -> String {
        format!(
            concat!(
                r#"<div id="asset-picker" class="picker-backdrop hidden">"#,
                r#"<div class="dialog picker-dialog asset-dialog">"#,
                r#"<div class="dialog-header"><span class="dialog-title">Pick Asset</span></div>"#,
                r#"<div class="dialog-content">"#,
                r#"<div class="asset-path-nav">"#,
                r#"<button id="asset-up" class="dialog-button">Up</button>"#,
                r#"<span id="asset-path" class="asset-path"></span></div>"#,
                r#"{grid}"#,
                r#"</div>"#,
                r#"<div class="dialog-footer">"#,
                r#"<button id="asset-ok" class="dialog-button primary">OK</button>"#,
                r#"<button id="asset-cancel" class="dialog-button">Cancel</button>"#,
                r#"</div></div></div>"#,
            ),
            grid = self.grid.container_rml(),
        )
    }

    fn bind_listeners(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        if self.bound {
            return Ok(());
        }
        let rml = interface.rml_ui();
        for (id, event) in [
            ("asset-ok", PickerEvent::Accept),
            ("asset-cancel", PickerEvent::Cancel),
            ("asset-up", PickerEvent::Up),
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

    fn set_visible(
        &self,
        interface: &NativeInterfaceRef,
        document: u64,
        visible: bool,
    ) -> Result<(), Error> {
        if let Some(e) = element_by_id(interface, document, "asset-picker") {
            interface
                .rml_ui()
                .element_set_class(e, "hidden", !visible)?;
        }
        Ok(())
    }

    fn populate(&mut self, interface: &NativeInterfaceRef, document: u64) -> Result<(), Error> {
        let extensions: Vec<&str> = self.extensions.iter().map(String::as_str).collect();
        self.grid.set_items(list_asset_tree(
            interface,
            &self.root,
            &self.dir,
            &extensions,
        ));
        self.grid.render(interface, document)?;
        if let Some(e) = element_by_id(interface, document, "asset-path") {
            interface
                .rml_ui()
                .element_set_inner_rml(e, &escape_rml(&self.dir))?;
        }
        if let Some(up) = element_by_id(interface, document, "asset-up") {
            // The top of the tree is the pack list; there is nothing above it.
            interface
                .rml_ui()
                .element_set_class(up, "disabled", self.dir.is_empty())?;
        }
        Ok(())
    }
}

impl Modal for AssetPicker {
    fn markup(&self) -> String {
        self.markup_rml()
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        _changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.bind_listeners(interface, document)
    }

    fn forget_bindings(&mut self) {
        self.bound = false;
        self.field = None;
        self.events.borrow_mut().clear();
        self.grid.drain_clicks();
    }

    fn is_open(&self) -> bool {
        self.field.is_some()
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
        Ok(true)
    }

    fn poll(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Vec<ModalEvent>, Error> {
        let field = self.field().map(str::to_string);
        let picked = self.tick(interface, document)?;
        let mut events = Vec::new();
        if let (Some(field), Some(path)) = (field, picked) {
            events.push(ModalEvent::FieldValue {
                field,
                value: FieldValue::Text(path),
                preview: false,
            });
        }
        Ok(events)
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}
