//! The shared modals: color picker, asset picker, file dialog, new-project.
//! One owner for opening, closing (Escape order), and polling them, so the
//! manager only routes their outcomes.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::actions::{self, FileAcceptFn, FileDialogConfig};
use crate::sbc::command_system::command::Command;
use crate::sbc::panels::controls::asset_picker::AssetPicker;
use crate::sbc::panels::controls::color_picker::{ColorPicker, PickerEvent};
use crate::sbc::panels::dialogs::file_dialog::FileDialog;
use crate::sbc::panels::field::FieldValue;
use crate::sbc::project::new_project_dialog::NewProjectDialog;

/// What a modal produced this tick, in the order it must be applied.
pub(crate) enum ModalEvent {
    /// Write a value into the active editor's field and dispatch its command;
    /// `preview` keeps it off the undo history.
    FieldValue {
        field: String,
        value: FieldValue,
        preview: bool,
    },
    Commands(Vec<Box<dyn Command>>),
}

#[derive(Default)]
pub(crate) struct ModalStack {
    picker: ColorPicker,
    asset_picker: AssetPicker,
    file_dialog: FileDialog,
    new_project: NewProjectDialog,
    /// The callback the open file dialog will run against its accepted result,
    /// set when a toolbar action opens the dialog.
    pending_accept: Option<FileAcceptFn>,
}

impl ModalStack {
    pub(crate) fn bind(&mut self, interface: &NativeInterfaceRef, doc: u64) -> Result<(), Error> {
        self.picker.bind(interface, doc)?;
        self.asset_picker.bind(interface, doc)?;
        self.file_dialog.bind(interface, doc)?;
        self.new_project.bind(interface, doc)
    }

    /// A fresh RmlUi context: every cached element handle is stale.
    pub(crate) fn forget_bindings(&mut self) {
        self.picker.forget_bindings();
        self.asset_picker.forget_bindings();
        self.file_dialog.forget_bindings();
        self.new_project.forget_bindings();
        self.pending_accept = None;
    }

    pub(crate) fn any_open(&self) -> bool {
        self.picker.is_open()
            || self.asset_picker.is_open()
            || self.file_dialog.is_open()
            || self.new_project.is_open()
    }

    /// Close the topmost open modal (Escape). Returns whether one was open.
    pub(crate) fn close_top(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
    ) -> Result<bool, Error> {
        if self.picker.is_open() {
            self.picker.close(interface, doc)?;
            return Ok(true);
        }
        if self.asset_picker.cancel_if_open(interface, doc)? {
            return Ok(true);
        }
        if self.file_dialog.cancel_if_open(interface, doc)? {
            self.pending_accept = None;
            return Ok(true);
        }
        self.new_project.cancel_if_open(interface, doc)
    }

    pub(crate) fn open_color(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
        field: &str,
        rgba: [f32; 4],
    ) -> Result<(), Error> {
        self.picker.open(interface, doc, field, rgba)
    }

    pub(crate) fn open_asset(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
        field: &str,
        root: &str,
        extensions: &[String],
    ) -> Result<(), Error> {
        let exts: Vec<&str> = extensions.iter().map(String::as_str).collect();
        self.asset_picker.open(interface, doc, field, root, &exts)
    }

    pub(crate) fn open_file(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
        config: FileDialogConfig,
        on_accept: FileAcceptFn,
    ) -> Result<(), Error> {
        self.pending_accept = Some(on_accept);
        self.file_dialog.open(interface, doc, config)
    }

    pub(crate) fn open_new_project(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
    ) -> Result<(), Error> {
        self.new_project.open(interface, doc)
    }

    /// Advance all four modals one tick and report what they produced.
    pub(crate) fn poll(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
    ) -> Result<Vec<ModalEvent>, Error> {
        let mut events = Vec::new();
        self.poll_picker(interface, doc, &mut events)?;
        self.poll_asset_picker(interface, doc, &mut events)?;
        self.poll_file_dialog(interface, doc, &mut events)?;
        self.poll_new_project(interface, doc, &mut events)?;
        Ok(events)
    }

    /// Dragging previews the colour on the engine every frame so the scene
    /// shows what is being picked; previews stay out of the undo history.
    /// Accepting dispatches exactly one undoable command, cancelling none.
    fn poll_picker(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
        events: &mut Vec<ModalEvent>,
    ) -> Result<(), Error> {
        if self.picker.tick(interface, doc) {
            if let Some(field) = self.picker.field().map(str::to_string) {
                events.push(ModalEvent::FieldValue {
                    field,
                    value: FieldValue::Color(self.picker.rgba()),
                    preview: true,
                });
            }
        }

        for event in self.picker.drain_events() {
            let Some(field) = self.picker.field().map(str::to_string) else {
                continue;
            };
            // The preview left the engine on some dragged colour. Undo has to
            // restore the colour the picker opened with, and the committed
            // command captures whatever it finds -- so put the original back
            // (as a preview, off-history) before committing.
            if self.picker.is_previewing() {
                events.push(ModalEvent::FieldValue {
                    field: field.clone(),
                    value: FieldValue::Color(self.picker.original()),
                    preview: true,
                });
            }
            if let PickerEvent::Accept = event {
                events.push(ModalEvent::FieldValue {
                    field,
                    value: FieldValue::Color(self.picker.rgba()),
                    preview: false,
                });
            }
            self.picker.close(interface, doc)?;
        }
        Ok(())
    }

    fn poll_asset_picker(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
        events: &mut Vec<ModalEvent>,
    ) -> Result<(), Error> {
        let field = self.asset_picker.field().map(str::to_string);
        let picked = self.asset_picker.tick(interface, doc)?;
        if let (Some(field), Some(path)) = (field, picked) {
            events.push(ModalEvent::FieldValue {
                field,
                value: FieldValue::Text(path),
                preview: false,
            });
        }
        Ok(())
    }

    fn poll_file_dialog(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
        events: &mut Vec<ModalEvent>,
    ) -> Result<(), Error> {
        if let Some(result) = self.file_dialog.tick(interface, doc)? {
            if let Some(on_accept) = self.pending_accept.take() {
                events.push(ModalEvent::Commands(on_accept(&result, interface)));
            }
        } else if !self.file_dialog.is_open() {
            // The dialog closed (cancel); drop any pending callback.
            self.pending_accept = None;
        }
        Ok(())
    }

    fn poll_new_project(
        &mut self,
        interface: &NativeInterfaceRef,
        doc: u64,
        events: &mut Vec<ModalEvent>,
    ) -> Result<(), Error> {
        if let Some(result) = self.new_project.tick(interface, doc)? {
            events.push(ModalEvent::Commands(actions::commit_new_project(
                &result.name,
                &result.map_name,
                result.size_x,
                result.size_y,
                interface,
            )));
        }
        Ok(())
    }
}
