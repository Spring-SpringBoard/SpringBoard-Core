//! The tooltip shown while hovering a unit or feature on the map.
//!
//! A port of `gui_rmlui_cursortip.lua`. Two things there are not obvious and are
//! kept: the pick is a small **screen rectangle**, not a ray, because the
//! engine's GUI ray does not report SpringBoard's own features; and the engine's
//! tooltip string is unusable ("No tooltip defined" for most editor objects), so
//! the text is built from what was hit.

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::panels::field::escape_rml;
use crate::sbc::rml::element_by_id;

/// Pick radius in pixels around the cursor, as Lua uses.
const PICK_RADIUS: f32 = 16.0;
const OFFSET_X: i32 = 16;
const OFFSET_Y: i32 = 12;

#[derive(Default)]
pub(crate) struct CursorTip {
    /// What is currently described, so the markup is only rewritten when the
    /// object under the cursor changes.
    shown: Option<String>,
}

impl CursorTip {
    pub(crate) fn update(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        over_panel: bool,
    ) -> Result<(), Error> {
        if crate::sbc::panels::field::tooltips_hidden() {
            return Ok(());
        }
        let Some(element) = element_by_id(interface, document, "native-tooltip") else {
            return Ok(());
        };
        let rml = interface.rml_ui();

        let Ok(mouse) = interface.input().get_mouse_state() else {
            return Ok(());
        };
        // Nothing while a button is down (a drag is in progress) or over the UI.
        let hit = if mouse.left || mouse.right || over_panel {
            None
        } else {
            self.pick(interface, mouse.x, mouse.y)
        };

        let Some(hit) = hit else {
            if self.shown.take().is_some() {
                rml.element_set_class(element, "hidden", true)?;
            }
            return Ok(());
        };

        if self.shown.as_deref() != Some(hit.key.as_str()) {
            rml.element_set_inner_rml(element, &hit.markup)?;
            self.shown = Some(hit.key);
        }
        rml.element_set_attribute(
            element,
            "style",
            &format!(
                "left: {}px; top: {}px;",
                mouse.x as i32 + OFFSET_X,
                mouse.y as i32 + OFFSET_Y
            ),
        )?;
        rml.element_set_class(element, "hidden", false)?;
        Ok(())
    }

    fn pick(&self, interface: &NativeInterfaceRef, x: f32, y: f32) -> Option<Hit> {
        // `get_mouse_state` measures y from the top; the screen-rectangle pick
        // wants it from the bottom, as the engine's own draw space does.
        let height = interface.display().get_view_geometry().ok()?.viewSizeY as f32;
        let y = height - 1.0 - y;
        let (left, right) = (x - PICK_RADIUS, x + PICK_RADIUS);
        let (top, bottom) = (y + PICK_RADIUS, y - PICK_RADIUS);

        let unsynced = interface.unsynced_read();
        let rendering = unsynced.unit_rendering();
        if let Ok(units) = rendering.get_units_in_screen_rectangle(left, top, right, bottom, -1) {
            if let Some(&unit_id) = units.first() {
                return describe_unit(interface, unit_id);
            }
        }
        // The pick matches an object's *drawPos* -- a tree's base, not its crown --
        // within PICK_RADIUS, so a hover that finds nothing is usually a hover on
        // the wrong part of the model.
        let features = rendering.get_features_in_screen_rectangle(left, top, right, bottom);
        describe_feature(interface, *features.ok()?.first()?)
    }
}

struct Hit {
    /// Identifies the object, so the markup is rebuilt only when it changes.
    key: String,
    markup: String,
}

fn describe_unit(interface: &NativeInterfaceRef, unit_id: i32) -> Option<Hit> {
    let units = interface.units_info();
    let def_id = units.get_unit_def_id(unit_id).ok()?;
    let defs = interface.unit_defs();
    let def_name = defs.get_unit_def_name(def_id).ok().flatten();
    let title = defs
        .get_unit_def_human_name(def_id)
        .ok()
        .flatten()
        .or_else(|| def_name.clone())?;

    let mut rows = Vec::new();
    // The def name under its human name: which *definition* this is is the thing
    // an editor needs, and two defs often share a human name.
    if let Some(name) = def_name.filter(|name| *name != title) {
        rows.push(name);
    }
    if let Ok(health) = units.get_unit_health(unit_id) {
        if health.maxHealth > 0.0 {
            rows.push(format!(
                "Health: {} / {}",
                health.health as i32, health.maxHealth as i32
            ));
        }
    }
    if let Ok(team) = units.get_unit_team(unit_id) {
        rows.push(format!("Team: {team}"));
    }
    if let Ok(experience) = units.get_unit_experience(unit_id) {
        if experience > 0.0 {
            rows.push(format!("Experience: {experience:.2}"));
        }
    }
    Some(Hit {
        key: format!("u{unit_id}"),
        markup: markup(&title, &rows),
    })
}

fn describe_feature(interface: &NativeInterfaceRef, feature_id: i32) -> Option<Hit> {
    let features = interface.features();
    let def_id = features.get_feature_def_id(feature_id).ok()?;
    let (info, true) = interface
        .feature_defs()
        .get_feature_def_by_id(def_id)
        .ok()?
    else {
        return None;
    };
    let name = cstr(info.name)?;
    // Lua titles the tip with the def's description and puts the name beneath.
    let title = cstr(info.description)
        .filter(|text| !text.trim().is_empty())
        .unwrap_or_else(|| name.clone());

    let mut rows = Vec::new();
    if name != title {
        rows.push(name);
    }
    if let Ok(health) = features.get_feature_health(feature_id) {
        if health.maxHealth > 0.0 {
            rows.push(format!(
                "Health: {} / {}",
                health.health as i32, health.maxHealth as i32
            ));
        }
    }
    // What it is worth to reclaim, which is most of why a feature is placed.
    if let Ok(resources) = features.get_feature_resources(feature_id) {
        if resources.metal > 0.0 || resources.energy > 0.0 {
            rows.push(format!(
                "Metal: {} Energy: {}",
                resources.metal as i32, resources.energy as i32
            ));
        }
        if resources.reclaimLeft > 0.0 && resources.reclaimLeft < 1.0 {
            rows.push(format!(
                "Reclaim left: {}%",
                (resources.reclaimLeft * 100.0) as i32
            ));
        }
    }
    Some(Hit {
        key: format!("f{feature_id}"),
        markup: markup(&title, &rows),
    })
}

fn cstr(ptr: *const std::ffi::c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    Some(
        unsafe { std::ffi::CStr::from_ptr(ptr) }
            .to_string_lossy()
            .into_owned(),
    )
}

fn markup(title: &str, rows: &[String]) -> String {
    let body: String = rows
        .iter()
        .map(|row| format!(r#"<div class="tip-row">{}</div>"#, escape_rml(row)))
        .collect();
    format!(
        r#"<div class="tip-title">{}</div>{body}"#,
        escape_rml(title)
    )
}
