//! The New Project dialog, a port of `RmlUiNewProjectWindow`.
//!
//! A custom modal (not the file browser): a project name, a map chosen from the
//! maps the VFS has an archive for, and — for the blank map — a size in map
//! units. On confirm it hands the manager the fields, which the action layer
//! turns into `SaveProjectInfoCommand` + `ReloadIntoProjectCommand`.

use std::any::Any;
use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataOptionRows, RmlDataVariable, RmlOptionRow,
};

use crate::sbc::actions::{available_maps, commit_new_project};
use crate::sbc::panels::controls::asset_picker::PickerEvent;
use crate::sbc::panels::dialogs::form::{DialogForm, FormItem};
use crate::sbc::panels::field::{element_by_id, ChangeQueue, FieldValue, InteractionQueue};
use crate::sbc::panels::fields::{ChoiceField, NumericField, StringField};
use crate::sbc::panels::modal::{Modal, ModalEvent};
use crate::sbc::panels::Editor;

inventory::submit! {
    crate::sbc::panels::modal::ModalRegistration {
        order: 3,
        make: || Box::new(NewProjectDialog::default()),
    }
}

/// The blank map's archive name; picking it reveals the size inputs.
const BLANK_MAP: &str = "SB_Blank_Map";

#[derive(Clone, Copy, PartialEq, Eq)]
enum NewProjectField {
    Name,
    Map,
    SizeX,
    SizeY,
}

use NewProjectField::*;

/// What the dialog produces on OK.
pub(crate) struct NewProjectResult {
    pub name: String,
    pub map_name: String,
    pub size_x: Option<f32>,
    pub size_y: Option<f32>,
}

pub(crate) struct NewProjectDialog {
    open: bool,
    events: Rc<RefCell<Vec<PickerEvent>>>,
    form: DialogForm<NewProjectField>,
    bound: bool,
    map_options: Option<RmlDataOptionRows<'static>>,
    hidden: Option<RmlDataVariable<'static, bool>>,
    show_blank_size: Option<RmlDataVariable<'static, bool>>,
}

impl Default for NewProjectDialog {
    fn default() -> Self {
        Self {
            open: false,
            events: Rc::new(RefCell::new(Vec::new())),
            form: new_project_form(),
            bound: false,
            map_options: None,
            hidden: None,
            show_blank_size: None,
        }
    }
}

impl NewProjectDialog {
    pub(crate) fn open(
        &mut self,
        interface: &NativeInterfaceRef,
        _document: u64,
    ) -> Result<(), Error> {
        // Populate the map dropdown: the blank map first, then everything the VFS
        // has an archive for.
        let options = std::iter::once(RmlOptionRow {
            value: BLANK_MAP.to_string(),
            label: "Blank".to_string(),
        })
        .chain(
            available_maps(interface)
                .into_iter()
                .filter(|map| map != BLANK_MAP)
                .map(|map| RmlOptionRow {
                    value: map.clone(),
                    label: map,
                }),
        )
        .collect::<Vec<_>>();
        self.map_options
            .as_ref()
            .expect("new-project options are bound before modal markup")
            .set(&options)?;
        self.form.set(Name, FieldValue::Text(String::new()));
        self.form.set(Map, FieldValue::Text(BLANK_MAP.to_string()));
        self.form.set(SizeX, FieldValue::Number(10.0));
        self.form.set(SizeY, FieldValue::Number(10.0));
        self.form.write(interface)?;
        self.show_blank_size
            .as_ref()
            .expect("new-project size visibility is bound before modal markup")
            .set(true)?;
        self.open = true;
        self.set_visible(true)
    }

    pub(crate) fn close(&mut self) -> Result<(), Error> {
        self.open = false;
        self.set_visible(false)
    }

    /// Drive the dialog. Returns the collected fields on OK.
    pub(crate) fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        _document: u64,
    ) -> Result<Option<NewProjectResult>, Error> {
        if !self.open {
            self.events.borrow_mut().clear();
            return Ok(None);
        }
        // Show the size inputs only for the blank map.
        let map = text_value(self.form.value(Map));
        self.show_blank_size
            .as_ref()
            .expect("new-project size visibility is bound before modal markup")
            .set(map == BLANK_MAP)?;

        let event = self.events.borrow_mut().drain(..).next();
        if let Some(event) = event {
            match event {
                PickerEvent::Cancel | PickerEvent::Up => {
                    self.close()?;
                    return Ok(None);
                }
                PickerEvent::Accept => {
                    for id in [Name, Map, SizeX, SizeY] {
                        self.form.commit(id, interface);
                    }
                    let name = text_value(self.form.value(Name)).trim().to_string();
                    if name.is_empty() {
                        // A project needs a name; keep the dialog open.
                        return Ok(None);
                    }
                    let map = text_value(self.form.value(Map));
                    let (size_x, size_y) = if map == BLANK_MAP {
                        (
                            number_value(self.form.value(SizeX)),
                            number_value(self.form.value(SizeY)),
                        )
                    } else {
                        (None, None)
                    };
                    self.close()?;
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

    fn markup_rml(&self) -> String {
        let fields = self.form.markup();
        format!(
            concat!(
                r#"<div id="new-project" class="picker-backdrop" data-model="new_project" data-class-hidden="hidden">"#,
                r#"<div class="dialog picker-dialog">"#,
                r#"<div class="dialog-header"><span class="dialog-title">New project</span></div>"#,
                r#"<div class="dialog-content">{fields}</div>"#,
                r#"<div class="dialog-footer">"#,
                r#"<button id="np-ok" class="dialog-button primary">Create</button>"#,
                r#"<button id="np-cancel" class="dialog-button">Cancel</button>"#,
                r#"</div></div></div>"#,
            ),
            fields = fields,
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
        self.form.bind(interface, document, changes, interactions)?;
        self.bound = true;
        Ok(())
    }

    fn set_visible(&self, visible: bool) -> Result<(), Error> {
        self.hidden
            .as_ref()
            .expect("new-project visibility is bound before modal markup")
            .set(!visible)
    }
}

impl Modal for NewProjectDialog {
    fn control_name(&self) -> Option<&'static str> {
        self.open.then_some("new_project")
    }

    fn control_field_name(&self, name: &str) -> Option<String> {
        match name {
            "name" => Some("np-name".to_string()),
            "map" => Some("np-map".to_string()),
            "size_x" => Some("np-size-x".to_string()),
            "size_y" => Some("np-size-y".to_string()),
            _ => None,
        }
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
            .create_data_model(context, "new_project")?;
        self.map_options = Some(data_model.bind_option_rows("maps")?);
        self.hidden = Some(data_model.bind("hidden", true)?);
        self.show_blank_size = Some(data_model.bind("show_blank_size", false)?);
        self.form.prepare_data_model(&data_model)?;
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
        self.open = false;
        self.events.borrow_mut().clear();
        self.map_options = None;
        self.hidden = None;
        self.show_blank_size = None;
    }

    fn is_open(&self) -> bool {
        self.open
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
        Ok(true)
    }

    fn poll(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Vec<ModalEvent>, Error> {
        let mut events = Vec::new();
        if let Some(result) = self.tick(interface, document)? {
            events.push(ModalEvent::Commands(commit_new_project(
                &result.name,
                &result.map_name,
                result.size_x,
                result.size_y,
                interface,
            )));
        }
        Ok(events)
    }

    fn field_editor(&self) -> Option<&dyn Editor> {
        self.open.then(|| self.form.editor())
    }

    fn field_editor_mut(&mut self) -> Option<&mut dyn Editor> {
        self.open.then(|| self.form.editor_mut())
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

fn new_project_form() -> DialogForm<NewProjectField> {
    DialogForm::new(
        vec![
            (
                Name,
                Box::new(StringField::new("np-name", "Project name", "")),
            ),
            (
                Map,
                Box::new(ChoiceField::new("np-map", "Map", Vec::new()).with_option_rows("maps")),
            ),
            (
                SizeX,
                Box::new(
                    NumericField::new("np-size-x", "Size X", 10.0)
                        .min(2.0)
                        .max(32.0)
                        .decimals(0)
                        .compact(),
                ),
            ),
            (
                SizeY,
                Box::new(
                    NumericField::new("np-size-y", "Size Y", 10.0)
                        .min(1.0)
                        .max(32.0)
                        .decimals(0)
                        .compact(),
                ),
            ),
        ],
        vec![
            FormItem::Field(Name),
            FormItem::Field(Map),
            FormItem::IdentifiedRowWhen(vec![SizeX, SizeY], "show_blank_size"),
        ],
    )
}

fn text_value(value: FieldValue) -> String {
    match value {
        FieldValue::Text(value) => value,
        _ => String::new(),
    }
}

fn number_value(value: FieldValue) -> Option<f32> {
    match value {
        // The dialog displays whole map units. Range-based dragging may hold a
        // fractional intermediate internally, so do not leak that into the
        // blank-map launch parameters.
        FieldValue::Number(value) => Some(value.round()),
        _ => None,
    }
}
