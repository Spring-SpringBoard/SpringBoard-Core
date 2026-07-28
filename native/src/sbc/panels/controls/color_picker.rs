//! Colour picker modal, a port of `scen_edit/view/rml/fields/color_picker.rml`.
//!
//! The saturation/value square and the hue strip are dragged against their own
//! rectangles, which the plugin reads with `element_get_rect` (the engine's
//! RmlUi feeds mouse input to its contexts directly, so a plugin never sees
//! `mouse_move` while a press is held; the cursor is polled instead).

use std::any::Any;
use std::cell::RefCell;
use std::rc::Rc;

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlColor, RmlDataVariable, RmlPixels,
};

use crate::sbc::panels::field::{element_by_id, FieldValue};
use crate::sbc::panels::modal::{Modal, ModalEvent};

inventory::submit! {
    crate::sbc::panels::modal::ModalRegistration {
        order: 0,
        make: || Box::new(ColorPicker::default()),
    }
}

const PICKER_MODEL: &str = "color_picker";
const PICKER_RML: &str = concat!(
    r#"<div id="color-picker" data-model="color_picker" class="picker-backdrop" data-class-hidden="hidden">"#,
    r#"<div id="picker-dialog" class="picker-dialog">"#,
    r#"<div class="dialog-header"><span class="dialog-title">Pick Color</span></div>"#,
    r#"<div class="dialog-content"><div class="color-picker-main">"#,
    r#"<div id="color-map" class="color-map" data-style-background-color="hue_colour">"#,
    r#"<img class="color-map-white" src="LuaUI/images/scenedit/color_picker/generated/sv_white.png"/>"#,
    r#"<img class="color-map-black" src="LuaUI/images/scenedit/color_picker/generated/sv_black.png"/>"#,
    r#"<div id="color-map-cursor" class="color-map-cursor" data-style-left="map_cursor_x" data-style-top="map_cursor_y"></div></div>"#,
    r#"<div id="hue-map" class="hue-map">"#,
    r#"<img src="LuaUI/images/scenedit/color_picker/H_grad.png"/><div id="hue-cursor" class="hue-cursor" data-style-top="hue_cursor_y"></div></div>"#,
    r#"<div class="color-side"><div class="color-preview" id="color-preview" data-style-background-color="preview_colour"></div></div>"#,
    r#"</div></div>"#,
    r#"<div class="dialog-footer">"#,
    r#"<button id="picker-ok" class="dialog-button primary">OK</button>"#,
    r#"<button id="picker-cancel" class="dialog-button">Cancel</button>"#,
    r#"</div></div></div>"#,
);

/// What the user grabbed, if anything.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Grab {
    None,
    Sv,
    Hue,
}

#[derive(Debug, Clone, Copy)]
pub(crate) enum PickerEvent {
    Accept,
    Cancel,
}

pub(crate) type PickerQueue = Rc<RefCell<Vec<PickerEvent>>>;

pub(crate) struct ColorPicker {
    /// The field this picker is editing.
    field: Option<String>,
    hsv: [f32; 3],
    alpha: f32,
    /// The colour the picker opened with. The live preview moves the engine off
    /// it, so both Accept and Cancel have to be able to put it back.
    original: [f32; 4],
    /// Whether the engine currently shows a previewed colour.
    previewing: bool,
    grab: Grab,
    bound: bool,
    events: PickerQueue,
    grab_queue: Rc<RefCell<Vec<Grab>>>,
    hue_colour: Option<RmlDataVariable<'static, RmlColor>>,
    preview_colour: Option<RmlDataVariable<'static, RmlColor>>,
    map_cursor_x: Option<RmlDataVariable<'static, RmlPixels>>,
    map_cursor_y: Option<RmlDataVariable<'static, RmlPixels>>,
    hue_cursor_y: Option<RmlDataVariable<'static, RmlPixels>>,
    hidden: Option<RmlDataVariable<'static, bool>>,
}

impl Default for ColorPicker {
    fn default() -> Self {
        ColorPicker {
            field: None,
            hsv: [0.0, 0.0, 1.0],
            alpha: 1.0,
            original: [1.0, 1.0, 1.0, 1.0],
            previewing: false,
            grab: Grab::None,
            bound: false,
            events: Rc::new(RefCell::new(Vec::new())),
            grab_queue: Rc::new(RefCell::new(Vec::new())),
            hue_colour: None,
            preview_colour: None,
            map_cursor_x: None,
            map_cursor_y: None,
            hue_cursor_y: None,
            hidden: None,
        }
    }
}

impl ColorPicker {
    pub(crate) fn field(&self) -> Option<&str> {
        self.field.as_deref()
    }

    pub(crate) fn rgba(&self) -> [f32; 4] {
        let [r, g, b] = hsv_to_rgb(self.hsv);
        [r, g, b, self.alpha]
    }

    pub(crate) fn original(&self) -> [f32; 4] {
        self.original
    }

    /// True once a drag has pushed a preview colour at the engine.
    pub(crate) fn is_previewing(&self) -> bool {
        self.previewing
    }

    pub(crate) fn open(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        field: &str,
        rgba: [f32; 4],
    ) -> Result<(), Error> {
        self.field = Some(field.to_string());
        self.hsv = rgb_to_hsv([rgba[0], rgba[1], rgba[2]]);
        self.alpha = rgba[3];
        self.original = rgba;
        self.previewing = false;
        self.grab = Grab::None;
        self.set_visible(true)?;
        self.sync(interface, document);
        Ok(())
    }

    pub(crate) fn close(&mut self) -> Result<(), Error> {
        self.field = None;
        self.grab = Grab::None;
        self.previewing = false;
        self.set_visible(false)
    }

    /// Drain OK/Cancel clicks.
    pub(crate) fn drain_events(&self) -> Vec<PickerEvent> {
        self.events.borrow_mut().drain(..).collect()
    }

    /// Advance a drag. Returns true if the colour changed.
    pub(crate) fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) -> bool {
        if !self.is_open() {
            self.grab_queue.borrow_mut().clear();
            return false;
        }
        if let Some(grab) = self.grab_queue.borrow_mut().drain(..).next_back() {
            self.grab = grab;
        }
        if self.grab == Grab::None {
            return false;
        }

        // The engine's mouse-button flags read as *released* while RmlUi holds the
        // press, so the pressed state comes from RmlUi's mousedown/mouseup (a
        // release anywhere lands on the backdrop). Only the position is polled.
        let Ok(mouse) = interface.input().get_mouse_state() else {
            return false;
        };

        // Engine mouse coordinates are bottom-origin; RmlUi rects are not.
        let Ok(geom) = interface.display().get_view_geometry() else {
            return false;
        };
        let (mx, my) = (mouse.x, geom.viewSizeY as f32 - mouse.y);

        let id = match self.grab {
            Grab::Sv => "color-map",
            Grab::Hue => "hue-map",
            Grab::None => return false,
        };
        let Some(element) = element_by_id(interface, document, id) else {
            return false;
        };
        let Ok((left, top, width, height)) = interface.rml_ui().element_get_rect(element) else {
            return false;
        };
        if width <= 0.0 || height <= 0.0 {
            return false;
        }

        match self.grab {
            Grab::Sv => {
                self.hsv[1] = ((mx - left) / width).clamp(0.0, 1.0);
                self.hsv[2] = 1.0 - ((my - top) / height).clamp(0.0, 1.0);
            }
            Grab::Hue => {
                self.hsv[0] = ((my - top) / height).clamp(0.0, 1.0);
            }
            Grab::None => return false,
        }
        self.sync(interface, document);
        self.previewing = true;
        true
    }

    /// Bind the picker's listeners once; the markup is created with the shell.
    fn bind_listeners(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        if self.bound {
            return Ok(());
        }
        let rml = interface.rml_ui();

        for (id, grab) in [("color-map", Grab::Sv), ("hue-map", Grab::Hue)] {
            let Some(e) = element_by_id(interface, document, id) else {
                continue;
            };
            let q = self.grab_queue.clone();
            rml.element_add_event_listener(e, "mousedown", false, move || {
                q.borrow_mut().push(grab);
            })?;
        }

        if let Some(e) = element_by_id(interface, document, "color-picker") {
            let q = self.grab_queue.clone();
            rml.element_add_event_listener(e, "mouseup", false, move || {
                q.borrow_mut().push(Grab::None);
            })?;
        }

        for (id, event) in [
            ("picker-ok", PickerEvent::Accept),
            ("picker-cancel", PickerEvent::Cancel),
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

    fn set_visible(&self, visible: bool) -> Result<(), Error> {
        self.hidden
            .as_ref()
            .expect("color-picker visibility is bound before modal markup")
            .set(!visible)
    }

    /// Push the current colour into the typed model. RmlUi receives native
    /// colours and pixel lengths, never generated CSS attributes.
    fn sync(&self, interface: &NativeInterfaceRef, document: u64) {
        let rml = interface.rml_ui();

        // The saturation/value square is tinted by the pure hue behind it.
        let pure = hsv_to_rgb([self.hsv[0], 1.0, 1.0]);
        set_colour(&self.hue_colour, pure, 1.0);
        set_colour(&self.preview_colour, hsv_to_rgb(self.hsv), self.alpha);
        if let Some(e) = element_by_id(interface, document, "color-map") {
            if let Ok((_, _, w, h)) = rml.element_get_rect(e) {
                set_pixels(&self.map_cursor_x, self.hsv[1] * w);
                set_pixels(&self.map_cursor_y, (1.0 - self.hsv[2]) * h);
            }
        }

        if let Some(e) = element_by_id(interface, document, "hue-map") {
            if let Ok((_, _, _, h)) = rml.element_get_rect(e) {
                set_pixels(&self.hue_cursor_y, self.hsv[0] * h);
            }
        }
    }
}

impl Modal for ColorPicker {
    fn prepare_data_model(
        &mut self,
        interface: &NativeInterfaceRef,
        context: u64,
    ) -> Result<(), Error> {
        let model = interface
            .rml_ui()
            .create_data_model(context, PICKER_MODEL)?;
        let transparent = RmlColor {
            red: 0,
            green: 0,
            blue: 0,
            alpha: 0,
        };
        self.hue_colour = Some(model.bind("hue_colour", transparent)?);
        self.preview_colour = Some(model.bind("preview_colour", transparent)?);
        self.map_cursor_x = Some(model.bind("map_cursor_x", RmlPixels(0.0))?);
        self.map_cursor_y = Some(model.bind("map_cursor_y", RmlPixels(0.0))?);
        self.hue_cursor_y = Some(model.bind("hue_cursor_y", RmlPixels(0.0))?);
        self.hidden = Some(model.bind("hidden", true)?);
        Ok(())
    }

    fn markup(&self) -> String {
        PICKER_RML.to_owned()
    }

    fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        _changes: &crate::sbc::panels::field::ChangeQueue,
        _interactions: &crate::sbc::panels::field::InteractionQueue,
    ) -> Result<(), Error> {
        self.bind_listeners(interface, document)
    }

    fn forget_bindings(&mut self) {
        self.bound = false;
        self.field = None;
        self.grab = Grab::None;
        self.previewing = false;
        self.events.borrow_mut().clear();
        self.grab_queue.borrow_mut().clear();
        self.hue_colour = None;
        self.preview_colour = None;
        self.map_cursor_x = None;
        self.map_cursor_y = None;
        self.hue_cursor_y = None;
        self.hidden = None;
    }

    fn is_open(&self) -> bool {
        self.field.is_some()
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

    /// Dragging previews the colour on the engine every frame so the scene shows
    /// what is being picked; previews stay out of the undo history. Accepting
    /// dispatches exactly one undoable command, cancelling none.
    fn poll(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<Vec<ModalEvent>, Error> {
        let mut events = Vec::new();
        if self.tick(interface, document) {
            if let Some(field) = self.field().map(str::to_string) {
                events.push(ModalEvent::FieldValue {
                    field,
                    value: FieldValue::Color(self.rgba()),
                    preview: true,
                });
            }
        }

        for event in self.drain_events() {
            let Some(field) = self.field().map(str::to_string) else {
                continue;
            };
            // The preview left the engine on some dragged colour. Undo has to
            // restore the colour the picker opened with, and the committed
            // command captures whatever it finds -- so put the original back
            // (as a preview, off-history) before committing.
            if self.is_previewing() {
                events.push(ModalEvent::FieldValue {
                    field: field.clone(),
                    value: FieldValue::Color(self.original()),
                    preview: true,
                });
            }
            if let PickerEvent::Accept = event {
                events.push(ModalEvent::FieldValue {
                    field,
                    value: FieldValue::Color(self.rgba()),
                    preview: false,
                });
            }
            self.close()?;
        }
        Ok(events)
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

fn set_colour(binding: &Option<RmlDataVariable<'static, RmlColor>>, rgb: [f32; 3], alpha: f32) {
    if let Some(binding) = binding {
        let _ = binding.set(RmlColor {
            red: (rgb[0].clamp(0.0, 1.0) * 255.0).round() as u8,
            green: (rgb[1].clamp(0.0, 1.0) * 255.0).round() as u8,
            blue: (rgb[2].clamp(0.0, 1.0) * 255.0).round() as u8,
            alpha: (alpha.clamp(0.0, 1.0) * 255.0).round() as u8,
        });
    }
}

fn set_pixels(binding: &Option<RmlDataVariable<'static, RmlPixels>>, value: f32) {
    if let Some(binding) = binding {
        let _ = binding.set(RmlPixels(value.max(0.0)));
    }
}

fn hsv_to_rgb(hsv: [f32; 3]) -> [f32; 3] {
    let [h, s, v] = hsv;
    let i = (h * 6.0).floor();
    let f = h * 6.0 - i;
    let p = v * (1.0 - s);
    let q = v * (1.0 - f * s);
    let t = v * (1.0 - (1.0 - f) * s);
    match (i as i32) % 6 {
        0 => [v, t, p],
        1 => [q, v, p],
        2 => [p, v, t],
        3 => [p, q, v],
        4 => [t, p, v],
        _ => [v, p, q],
    }
}

fn rgb_to_hsv(rgb: [f32; 3]) -> [f32; 3] {
    let [r, g, b] = rgb;
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let d = max - min;
    let v = max;
    let s = if max <= 0.0 { 0.0 } else { d / max };
    if d <= 0.0 {
        return [0.0, s, v];
    }
    let h = if max == r {
        ((g - b) / d).rem_euclid(6.0)
    } else if max == g {
        (b - r) / d + 2.0
    } else {
        (r - g) / d + 4.0
    };
    [h / 6.0, s, v]
}

#[cfg(test)]
mod tests {
    use super::*;

    fn close(a: [f32; 3], b: [f32; 3]) -> bool {
        a.iter().zip(b).all(|(x, y)| (x - y).abs() < 1e-4)
    }

    #[test]
    fn hsv_round_trips_through_rgb() {
        for rgb in [
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
            [0.25, 0.5, 0.75],
            [0.5, 0.5, 0.5],
            [0.0, 0.0, 0.0],
        ] {
            assert!(
                close(hsv_to_rgb(rgb_to_hsv(rgb)), rgb),
                "round trip failed for {rgb:?}"
            );
        }
    }

    #[test]
    fn pure_hues_land_on_the_expected_primaries() {
        assert!(close(hsv_to_rgb([0.0, 1.0, 1.0]), [1.0, 0.0, 0.0]));
        assert!(close(hsv_to_rgb([1.0 / 3.0, 1.0, 1.0]), [0.0, 1.0, 0.0]));
        assert!(close(hsv_to_rgb([2.0 / 3.0, 1.0, 1.0]), [0.0, 0.0, 1.0]));
    }
}
