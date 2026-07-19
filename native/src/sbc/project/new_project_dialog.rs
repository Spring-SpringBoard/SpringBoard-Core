//! The New Project dialog, a port of `RmlUiNewProjectWindow`.
//!
//! A custom modal (not the file browser): a project name, a map chosen from the
//! maps the VFS has an archive for, and — for the blank map — a size in map
//! units. On confirm it hands the manager the fields, which the action layer
//! turns into `SaveProjectInfoCommand` + `ReloadIntoProjectCommand`.

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::actions::available_maps;
use crate::sbc::panels::controls::asset_picker::PickerEvent;
use crate::sbc::panels::field::{element_by_id, escape_rml};

/// The blank map's archive name; picking it reveals the size inputs.
const BLANK_MAP: &str = "SB_Blank_Map";

/// What the dialog produces on OK.
pub(crate) struct NewProjectResult {
    pub name: String,
    pub map_name: String,
    pub size_x: Option<f32>,
    pub size_y: Option<f32>,
}

#[derive(Default)]
pub(crate) struct NewProjectDialog {
    open: bool,
    events: Rc<RefCell<Vec<PickerEvent>>>,
    bound: bool,
}

impl NewProjectDialog {
    pub(crate) fn is_open(&self) -> bool {
        self.open
    }

    pub(crate) fn forget_bindings(&mut self) {
        self.bound = false;
        self.open = false;
        self.events.borrow_mut().clear();
    }

    pub(crate) fn markup() -> String {
        concat!(
            r#"<div id="new-project" class="picker-backdrop hidden">"#,
            r#"<div class="dialog picker-dialog">"#,
            r#"<div class="dialog-header"><span class="dialog-title">New project</span></div>"#,
            r#"<div class="dialog-content">"#,
            r#"<div class="fd-row"><label class="fd-label">Name</label>"#,
            r#"<input type="text" id="np-name" class="fd-input" value=""/></div>"#,
            r#"<div class="fd-row"><label class="fd-label">Map</label>"#,
            r#"<select id="np-map" class="fd-input"></select></div>"#,
            r#"<div id="np-size-row" class="fd-row hidden"><label class="fd-label">Size</label>"#,
            r#"<input type="text" id="np-size-x" class="fd-input fd-size" value="10"/>"#,
            r#"<input type="text" id="np-size-y" class="fd-input fd-size" value="10"/></div>"#,
            r#"</div>"#,
            r#"<div class="dialog-footer">"#,
            r#"<button id="np-ok" class="dialog-button primary">Create</button>"#,
            r#"<button id="np-cancel" class="dialog-button">Cancel</button>"#,
            r#"</div></div></div>"#,
        )
        .to_string()
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
            ("np-ok", PickerEvent::Accept),
            ("np-cancel", PickerEvent::Cancel),
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
    ) -> Result<(), Error> {
        let rml = interface.rml_ui();
        // Populate the map dropdown: the blank map first, then everything the VFS
        // has an archive for.
        let mut opts = format!(r#"<option value="{BLANK_MAP}">Empty map</option>"#);
        for map in available_maps(interface) {
            if map == BLANK_MAP {
                continue;
            }
            opts.push_str(&format!(
                r#"<option value="{v}">{v}</option>"#,
                v = escape_rml(&map)
            ));
        }
        if let Some(e) = element_by_id(interface, document, "np-map") {
            rml.element_set_inner_rml(e, &opts)?;
        }
        if let Some(e) = element_by_id(interface, document, "np-name") {
            rml.element_set_attribute(e, "value", "")?;
        }
        self.open = true;
        self.set_visible(interface, document, true)
    }

    pub(crate) fn close(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        self.open = false;
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

    /// Drive the dialog. Returns the collected fields on OK.
    pub(crate) fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Option<NewProjectResult>, Error> {
        if !self.open {
            self.events.borrow_mut().clear();
            return Ok(None);
        }
        let rml = interface.rml_ui();

        // Show the size inputs only for the blank map.
        let map = element_by_id(interface, document, "np-map")
            .and_then(|e| rml.element_get_value(e).ok().flatten())
            .unwrap_or_else(|| BLANK_MAP.to_string());
        if let Some(e) = element_by_id(interface, document, "np-size-row") {
            rml.element_set_class(e, "hidden", map != BLANK_MAP)?;
        }

        let event = self.events.borrow_mut().drain(..).next();
        if let Some(event) = event {
            match event {
                PickerEvent::Cancel | PickerEvent::Up => {
                    self.close(interface, document)?;
                    return Ok(None);
                }
                PickerEvent::Accept => {
                    let name = element_by_id(interface, document, "np-name")
                        .and_then(|e| rml.element_get_value(e).ok().flatten())
                        .map(|s| s.trim().to_string())
                        .unwrap_or_default();
                    if name.is_empty() {
                        // A project needs a name; keep the dialog open.
                        return Ok(None);
                    }
                    let (size_x, size_y) = if map == BLANK_MAP {
                        (
                            read_size(interface, document, "np-size-x"),
                            read_size(interface, document, "np-size-y"),
                        )
                    } else {
                        (None, None)
                    };
                    self.close(interface, document)?;
                    return Ok(Some(NewProjectResult {
                        name,
                        map_name: map,
                        size_x,
                        size_y,
                    }));
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
        if let Some(e) = element_by_id(interface, document, "new-project") {
            interface
                .rml_ui()
                .element_set_class(e, "hidden", !visible)?;
        }
        Ok(())
    }
}

fn read_size(interface: &NativeInterfaceRef, document: u64, id: &str) -> Option<f32> {
    element_by_id(interface, document, id)
        .and_then(|e| interface.rml_ui().element_get_value(e).ok().flatten())
        .and_then(|s| s.trim().parse::<f32>().ok())
}
