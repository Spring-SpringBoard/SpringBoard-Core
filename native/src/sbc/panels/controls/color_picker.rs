//! Colour picker modal, a port of `scen_edit/view/rml/fields/color_picker.rml`.
//!
//! The saturation/value square and the hue strip are dragged against their own
//! rectangles, which the plugin reads with `element_get_rect` (the engine's
//! RmlUi feeds mouse input to its contexts directly, so a plugin never sees
//! `mouse_move` while a press is held; the cursor is polled instead).

use std::any::Any;
use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::{element_by_id, FieldValue};
use crate::sbc::panels::modal::{Modal, ModalEvent};

inventory::submit! {
    crate::sbc::panels::modal::ModalRegistration {
        order: 0,
        make: || Box::new(ColorPicker::default()),
    }
}

const IMG_SV_WHITE: &str = "LuaUI/images/scenedit/color_picker/generated/sv_white.png";
const IMG_SV_BLACK: &str = "LuaUI/images/scenedit/color_picker/generated/sv_black.png";
const IMG_HUE: &str = "LuaUI/images/scenedit/color_picker/H_grad.png";

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

    fn markup_rml() -> String {
        format!(
            concat!(
                r#"<div id="color-picker" class="picker-backdrop hidden">"#,
                r#"<div id="picker-dialog" class="picker-dialog">"#,
                r#"<div class="dialog-header"><span class="dialog-title">Pick Color</span></div>"#,
                r#"<div class="dialog-content"><div class="color-picker-main">"#,
                r#"<div id="color-map" class="color-map">"#,
                r#"<img class="color-map-white" src="{white}"/>"#,
                r#"<img class="color-map-black" src="{black}"/>"#,
                r#"<div id="color-map-cursor" class="color-map-cursor"></div></div>"#,
                r#"<div id="hue-map" class="hue-map">"#,
                r#"<img src="{hue}"/><div id="hue-cursor" class="hue-cursor"></div></div>"#,
                r#"<div class="color-side"><div class="color-preview" id="color-preview"></div></div>"#,
                r#"</div></div>"#,
                r#"<div class="dialog-footer">"#,
                r#"<button id="picker-ok" class="dialog-button primary">OK</button>"#,
                r#"<button id="picker-cancel" class="dialog-button">Cancel</button>"#,
                r#"</div></div></div>"#,
            ),
            white = IMG_SV_WHITE,
            black = IMG_SV_BLACK,
            hue = IMG_HUE,
        )
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
        self.set_visible(interface, document, true)?;
        self.sync(interface, document);
        Ok(())
    }

    pub(crate) fn close(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        self.field = None;
        self.grab = Grab::None;
        self.previewing = false;
        self.set_visible(interface, document, false)
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

    fn set_visible(
        &self,
        interface: &NativeInterfaceRef,
        document: u64,
        visible: bool,
    ) -> Result<(), Error> {
        if let Some(e) = element_by_id(interface, document, "color-picker") {
            interface
                .rml_ui()
                .element_set_class(e, "hidden", !visible)?;
        }
        Ok(())
    }

    /// Push the current colour into the DOM: hue backdrop, cursors, preview.
    fn sync(&self, interface: &NativeInterfaceRef, document: u64) {
        let rml = interface.rml_ui();

        // The saturation/value square is tinted by the pure hue behind it.
        let pure = hsv_to_rgb([self.hsv[0], 1.0, 1.0]);
        if let Some(e) = element_by_id(interface, document, "color-map") {
            let _ =
                rml.element_set_attribute(e, "style", &format!("background-color: {};", css(pure)));
            if let Ok((_, _, w, h)) = rml.element_get_rect(e) {
                if let Some(cursor) = element_by_id(interface, document, "color-map-cursor") {
                    let _ = rml.element_set_attribute(
                        cursor,
                        "style",
                        &format!(
                            "left: {}px; top: {}px;",
                            (self.hsv[1] * w) as i32,
                            ((1.0 - self.hsv[2]) * h) as i32
                        ),
                    );
                }
            }
        }

        if let Some(e) = element_by_id(interface, document, "hue-map") {
            if let Ok((_, _, _, h)) = rml.element_get_rect(e) {
                if let Some(cursor) = element_by_id(interface, document, "hue-cursor") {
                    let _ = rml.element_set_attribute(
                        cursor,
                        "style",
                        &format!("top: {}px;", (self.hsv[0] * h) as i32),
                    );
                }
            }
        }

        if let Some(e) = element_by_id(interface, document, "color-preview") {
            let [r, g, b] = hsv_to_rgb(self.hsv);
            let _ = rml.element_set_attribute(
                e,
                "style",
                &format!("background-color: {};", css([r, g, b])),
            );
        }
    }
}

impl Modal for ColorPicker {
    fn markup(&self) -> String {
        Self::markup_rml()
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
            self.close(interface, document)?;
        }
        Ok(events)
    }

    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

fn css(rgb: [f32; 3]) -> String {
    format!(
        "#{:02x}{:02x}{:02x}",
        (rgb[0] * 255.0).clamp(0.0, 255.0) as u8,
        (rgb[1] * 255.0).clamp(0.0, 255.0) as u8,
        (rgb[2] * 255.0).clamp(0.0, 255.0) as u8,
    )
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
