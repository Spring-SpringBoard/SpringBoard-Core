//! Shared body of the Objects tab's Units and Features views.
//!
//! A view is: Add / Brush mode buttons, a team + placement fields, a search box,
//! and a grid of definitions. Selecting a definition (or changing a setting
//! while one is selected) arms the map click to place it.
//!
//! Not ported: per-cell **thumbnails** (Lua renders each def to a dynamic
//! texture via `<texture src="!N">`; there is no native render-to-texture
//! binding), and for units the **type/terrain filters** (need unit-def category
//! bindings that are not exposed). Build pictures are deliberately not used as a
//! thumbnail substitute — many games have none.

use std::cell::RefCell;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor_base::{group_rml, resolve_base, section_rml, FieldSet};
use crate::sbc::panels::field::{escape_rml, ChangeQueue, InteractionQueue};
use crate::sbc::panels::fields::{ChoiceField, NumericField};
use crate::sbc::panels::grid::{GridItem, GridView};
use crate::sbc::panels::thumbnails::{ThumbKind, ThumbnailRenderer};
use crate::sbc::rml::element_by_id;
use crate::sbc::states::{PlacementConfig, StateRequest};
use crate::sbc::teams::TeamManager;

/// Which definitions a view lists.
#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum DefKind {
    Unit,
    Feature,
}

/// Placement mode, chosen by the two buttons. Ports Lua's Add / Brush.
#[derive(Clone, Copy, PartialEq, Eq)]
enum PlaceMode {
    Set,
    Brush,
}

/// Set-mode fields, then brush-mode fields; the ones for the inactive mode are
/// hidden, as Lua does with `SetInvisibleFields`.
const SET_FIELDS: &[&str] = &["amount"];
const BRUSH_FIELDS: &[&str] = &["size", "spread", "rotYMin", "rotYMax"];

pub(crate) struct ObjectDefsView {
    kind: DefKind,
    grid: GridView,
    /// Every definition, unfiltered; the grid holds the filtered subset.
    all: Vec<GridItem>,
    search: String,
    search_element: Option<u64>,
    loaded: bool,
    search_dirty: bool,
    /// A definition was just clicked, or a setting changed with one selected;
    /// either re-arms placement.
    request_dirty: bool,

    fields: FieldSet,
    mode: PlaceMode,
    mode_clicks: Rc<RefCell<Vec<PlaceMode>>>,
    /// Team captions in the choice, paired with their ids.
    teams: Vec<(i32, String)>,
    teams_revision: usize,
    /// The field set or mode changed, so the markup must be regenerated.
    needs_rebuild: bool,
    /// Renders each def's model into a texture for its grid cell.
    thumbnails: ThumbnailRenderer,
}

impl ObjectDefsView {
    pub(crate) fn new(kind: DefKind) -> Self {
        ObjectDefsView {
            kind,
            grid: GridView::new("object-defs-grid", 64),
            all: Vec::new(),
            search: String::new(),
            search_element: None,
            loaded: false,
            search_dirty: false,
            request_dirty: false,
            fields: FieldSet::new(vec![
                Box::new(ChoiceField::new("team", "Team", vec![])),
                Box::new(
                    NumericField::new("amount", "Amount", 1.0)
                        .min(1.0)
                        .max(100.0)
                        .decimals(0),
                ),
                Box::new(
                    NumericField::new("size", "Size", 100.0)
                        .min(10.0)
                        .max(5000.0)
                        .decimals(0),
                ),
                Box::new(
                    NumericField::new("spread", "Spread", 100.0)
                        .min(1.0)
                        .max(500.0)
                        .decimals(0),
                ),
                Box::new(
                    NumericField::new("rotYMin", "Min yaw", 0.0)
                        .min(-180.0)
                        .max(180.0)
                        .decimals(0),
                ),
                Box::new(
                    NumericField::new("rotYMax", "Max yaw", 0.0)
                        .min(-180.0)
                        .max(180.0)
                        .decimals(0),
                ),
            ]),
            mode: PlaceMode::Set,
            mode_clicks: Rc::new(RefCell::new(Vec::new())),
            teams: Vec::new(),
            teams_revision: usize::MAX,
            needs_rebuild: false,
            thumbnails: ThumbnailRenderer::default(),
        }
    }

    /// Create/redraw the def thumbnails. Runs on the draw thread.
    pub(crate) fn draw_thumbnails(&mut self, interface: &NativeInterfaceRef) {
        self.thumbnails.draw(interface);
    }

    pub(crate) fn mark_search_dirty(&mut self) {
        self.search_dirty = true;
    }

    /// A placement field committed; re-arm placement with the new setting.
    pub(crate) fn note_field_change(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.read(resolve_base(name), interface);
        self.request_dirty = true;
    }

    pub(crate) fn generate_rml(&self) -> String {
        let mut h = String::from(r#"<div class="brush-actions">"#);
        for (mode, caption) in [(PlaceMode::Set, "Add"), (PlaceMode::Brush, "Brush")] {
            let pressed = if mode == self.mode { " pressed" } else { "" };
            let id = if mode == PlaceMode::Set {
                "objectdef-mode-add"
            } else {
                "objectdef-mode-brush"
            };
            h.push_str(&format!(
                r#"<button id="{id}" class="brush-action{pressed}">{caption}</button>"#,
            ));
        }
        h.push_str("</div>");

        h.push_str(&self.fields.rml("team"));
        // Only the active mode's fields.
        for name in self.mode_fields() {
            h.push_str(&self.fields.rml(name));
        }
        if self.mode == PlaceMode::Brush {
            h.push_str(&group_rml(&[
                self.fields.rml("rotYMin"),
                self.fields.rml("rotYMax"),
            ]));
        }

        h.push_str(&section_rml("Definitions"));
        h.push_str(&format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<span class="field-label">Search:</span>"#,
                r#"<input type="text" id="object-defs-search" class="field-input"/>"#,
                r#"</div>{grid}"#,
            ),
            grid = self.grid.container_rml(),
        ));
        h
    }

    fn mode_fields(&self) -> &'static [&'static str] {
        match self.mode {
            PlaceMode::Set => SET_FIELDS,
            // rotY fields render in their own group, not the flat list.
            PlaceMode::Brush => &["size", "spread"],
        }
    }

    pub(crate) fn is_placement_field(&self, name: &str) -> bool {
        let base = resolve_base(name);
        base == "team" || SET_FIELDS.contains(&base) || BRUSH_FIELDS.contains(&base)
    }

    pub(crate) fn bind(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.fields
            .bind(interface, document, changes, interactions)?;

        self.search_element = element_by_id(interface, document, "object-defs-search");
        if let Some(element) = self.search_element {
            let queue = changes.clone();
            interface
                .rml_ui()
                .element_add_event_listener(element, "change", false, move || {
                    queue
                        .borrow_mut()
                        .push(crate::sbc::panels::field::CommitRequest {
                            field: "search".to_string(),
                            from_blur: false,
                        });
                })?;
        }

        for (id, mode) in [
            ("objectdef-mode-add", PlaceMode::Set),
            ("objectdef-mode-brush", PlaceMode::Brush),
        ] {
            if let Some(button) = element_by_id(interface, document, id) {
                let queue = self.mode_clicks.clone();
                interface.rml_ui().element_add_event_listener(
                    button,
                    "click",
                    false,
                    move || {
                        queue.borrow_mut().push(mode);
                    },
                )?;
            }
        }
        Ok(())
    }

    /// Populate the team choice from the model. Returns true if the roster
    /// changed and the markup must be regenerated (the choice's options did).
    pub(crate) fn refresh_teams(&mut self, models: &mut Models) -> bool {
        let teams = models.get::<TeamManager>().all_teams();
        let revision = teams.len();
        if revision == self.teams_revision {
            return false;
        }
        self.teams_revision = revision;
        self.teams = teams
            .iter()
            .map(|t| (t.id, format!("Team {}", t.id)))
            .collect();
        self.rebuild_fields();
        self.needs_rebuild = true;
        true
    }

    /// Rebuild the field set: the team choice's options come from the roster,
    /// which changes, so the field cannot be fixed at construction.
    fn rebuild_fields(&mut self) {
        let captions: Vec<String> = self.teams.iter().map(|(_, c)| c.clone()).collect();
        self.fields = FieldSet::new(vec![
            Box::new(ChoiceField::new("team", "Team", captions)),
            Box::new(
                NumericField::new("amount", "Amount", 1.0)
                    .min(1.0)
                    .max(100.0)
                    .decimals(0),
            ),
            Box::new(
                NumericField::new("size", "Size", 100.0)
                    .min(10.0)
                    .max(5000.0)
                    .decimals(0),
            ),
            Box::new(
                NumericField::new("spread", "Spread", 100.0)
                    .min(1.0)
                    .max(500.0)
                    .decimals(0),
            ),
            Box::new(
                NumericField::new("rotYMin", "Min yaw", 0.0)
                    .min(-180.0)
                    .max(180.0)
                    .decimals(0),
            ),
            Box::new(
                NumericField::new("rotYMax", "Max yaw", 0.0)
                    .min(-180.0)
                    .max(180.0)
                    .decimals(0),
            ),
        ]);
    }

    /// The placement config from the current fields.
    fn config(&self) -> PlacementConfig {
        let team = self
            .selected_team()
            .unwrap_or_else(|| self.teams.first().map(|(id, _)| *id).unwrap_or(0));
        PlacementConfig {
            team,
            brush: self.mode == PlaceMode::Brush,
            amount: self.fields.number("amount").max(1.0) as u32,
            size: self.fields.number("size"),
            yaw_min: self.fields.number("rotYMin").to_radians(),
            yaw_max: self.fields.number("rotYMax").to_radians(),
        }
    }

    fn selected_team(&self) -> Option<i32> {
        let caption = self.fields.text("team");
        self.teams
            .iter()
            .find(|(_, c)| *c == caption)
            .map(|(id, _)| *id)
    }

    /// Load defs, handle search + grid + mode clicks, and re-arm placement.
    pub(crate) fn tick(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        if !self.loaded {
            let (loaded, thumb_kind) = match self.kind {
                DefKind::Unit => (unit_defs(interface), ThumbKind::Unit),
                DefKind::Feature => (feature_defs(interface), ThumbKind::Feature),
            };
            for (item, def_id) in &loaded {
                self.thumbnails.request(&item.id, *def_id, thumb_kind);
            }
            self.all = loaded.into_iter().map(|(item, _)| item).collect();
            self.loaded = true;
            self.apply_filter(interface, document)?;
        }

        // Thumbnails are created on the draw thread; when their names appear,
        // point each grid cell at its texture and re-render.
        if self.thumbnails.take_names_dirty() {
            let names: Vec<(String, Option<String>)> = self
                .all
                .iter()
                .filter(|item| item.image.is_none())
                .map(|item| {
                    (
                        item.id.clone(),
                        self.thumbnails.texture_for(&item.id).map(str::to_string),
                    )
                })
                .collect();
            for (id, texture) in names {
                if let Some(item) = self.all.iter_mut().find(|i| i.id == id) {
                    item.image = texture;
                }
            }
            self.apply_filter(interface, document)?;
        }

        if self.search_dirty {
            self.search_dirty = false;
            if let Some(element) = self.search_element {
                if let Ok((Some(value), true)) =
                    interface.rml_ui().element_get_attribute(element, "value")
                {
                    self.search = value.to_lowercase();
                }
            }
            self.apply_filter(interface, document)?;
        }

        for id in self.grid.drain_clicks() {
            self.grid.set_selected(Some(&id));
            self.request_dirty = true;
            self.grid.render(interface, document)?;
        }

        // Keep the thumbnails tinted for the chosen team.
        if let Some(team) = self.selected_team() {
            self.thumbnails.set_team(team);
        }

        let mode_change = self.mode_clicks.borrow_mut().drain(..).next_back();
        if let Some(mode) = mode_change {
            if mode != self.mode {
                self.mode = mode;
                self.needs_rebuild = true;
            }
            self.request_dirty = true;
        }
        Ok(())
    }

    /// Whether the view needs a refresh + rebuild: the team roster changed, or a
    /// mode switch changed which fields show. Consumes the pending rebuild.
    pub(crate) fn poll_refresh(&mut self, models: &mut Models) -> bool {
        let teams_changed = self.refresh_teams(models);
        let pending = std::mem::take(&mut self.needs_rebuild);
        teams_changed || pending
    }

    // Field passthroughs, so the thin view wrappers do not each re-list them.
    pub(crate) fn drag_field(
        &mut self,
        name: &str,
        dx: f32,
        interface: &NativeInterfaceRef,
    ) -> bool {
        self.fields.drag(name, dx, interface)
    }
    pub(crate) fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
        self.fields.drag_end(name, interface)
    }
    pub(crate) fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.begin_edit(name, interface)
    }
    pub(crate) fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        self.fields.cancel_edit(name, interface)
    }
    pub(crate) fn field_value(&self, name: &str) -> crate::sbc::panels::field::FieldValue {
        self.fields.value(name)
    }
    pub(crate) fn set_field_value(
        &mut self,
        name: &str,
        value: crate::sbc::panels::field::FieldValue,
        interface: &NativeInterfaceRef,
    ) {
        self.fields.set(resolve_base(name), value);
        self.request_dirty = true;
        let _ = self.fields.write_values(interface);
    }

    /// The placement state to enter, if a definition is selected and something
    /// changed. Ports `ObjectDefsView:EnterState`.
    pub(crate) fn take_state_request(&mut self) -> Option<StateRequest> {
        if !std::mem::take(&mut self.request_dirty) {
            return None;
        }
        let Some(def) = self.grid.selected().map(str::to_string) else {
            return Some(StateRequest::Default);
        };
        let config = self.config();
        Some(match self.kind {
            DefKind::Unit => StateRequest::AddUnit(def, config),
            DefKind::Feature => StateRequest::AddFeature(def, config),
        })
    }

    pub(crate) fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn apply_filter(&mut self, interface: &NativeInterfaceRef, document: u64) -> Result<(), Error> {
        let matches: Vec<GridItem> = self
            .all
            .iter()
            .filter(|item| {
                self.search.is_empty()
                    || item.caption.to_lowercase().contains(&self.search)
                    || item.id.to_lowercase().contains(&self.search)
            })
            .cloned()
            .collect();
        self.grid.set_items(matches);
        self.grid.render(interface, document)
    }
}

/// The `Editor` impl shared by the Units and Features wrappers: both are a thin
/// `{ defs: ObjectDefsView }` that forwards everything.
macro_rules! object_defs_editor {
    ($ty:ty) => {
        impl crate::sbc::panels::editor::Editor for $ty {
            fn generate_rml(&self) -> String {
                self.defs.generate_rml()
            }
            fn bind_fields(
                &mut self,
                interface: &NativeInterfaceRef,
                document: u64,
                changes: &crate::sbc::panels::field::ChangeQueue,
                interactions: &crate::sbc::panels::field::InteractionQueue,
            ) -> Result<(), Error> {
                self.defs.bind(interface, document, changes, interactions)
            }
            fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
                self.defs.write_field_values(interface)
            }
            fn tick(
                &mut self,
                interface: &NativeInterfaceRef,
                document: u64,
                _next: &mut u64,
            ) -> Vec<String> {
                let _ = self.defs.tick(interface, document);
                vec![]
            }
            fn take_state_request(&mut self) -> Option<crate::sbc::states::StateRequest> {
                self.defs.take_state_request()
            }
            fn wants_refresh(
                &mut self,
                models: &mut crate::sbc::command_system::model::Models,
            ) -> bool {
                // The team roster and the mode buttons are the external state; a
                // change to either regenerates the markup.
                self.defs.poll_refresh(models)
            }
            fn wants_rebuild(&self) -> bool {
                true
            }
            fn refresh_from_engine(
                &mut self,
                _interface: &NativeInterfaceRef,
                models: &mut crate::sbc::command_system::model::Models,
            ) {
                self.defs.refresh_teams(models);
            }
            /// A search commit re-filters; a placement field commit re-arms.
            fn process_change(
                &mut self,
                name: &str,
                interface: &NativeInterfaceRef,
                _next: &mut u64,
            ) -> Vec<String> {
                if self.defs.is_placement_field(name) {
                    self.defs.note_field_change(name, interface);
                } else {
                    self.defs.mark_search_dirty();
                }
                vec![]
            }
            fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
                vec![]
            }
            fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
                self.defs.drag_field(name, dx, interface)
            }
            fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
                self.defs.drag_end_field(name, interface)
            }
            fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
                self.defs.begin_edit_field(name, interface)
            }
            fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
                self.defs.cancel_edit_field(name, interface)
            }
            fn field_value(&self, name: &str) -> crate::sbc::panels::field::FieldValue {
                self.defs.field_value(name)
            }
            fn set_field_value(
                &mut self,
                name: &str,
                value: crate::sbc::panels::field::FieldValue,
                interface: &NativeInterfaceRef,
            ) {
                self.defs.set_field_value(name, value, interface)
            }
            fn field_asset(&self, _name: &str) -> Option<(String, Vec<String>)> {
                None
            }
            fn draw_thumbnails(&mut self, interface: &NativeInterfaceRef) {
                self.defs.draw_thumbnails(interface)
            }
        }
    };
}

pub(crate) use object_defs_editor;

/// Each grid item paired with its engine def id, for the thumbnail renderer.
fn unit_defs(interface: &NativeInterfaceRef) -> Vec<(GridItem, i32)> {
    let defs = interface.unit_defs();
    let count = defs.get_unit_def_count().unwrap_or(0);
    let mut items = Vec::new();
    for id in 1..=count as i32 {
        let Ok(Some(name)) = defs.get_unit_def_name(id) else {
            continue;
        };
        let caption = defs
            .get_unit_def_human_name(id)
            .ok()
            .flatten()
            .unwrap_or_else(|| name.clone());
        items.push((
            GridItem {
                id: name,
                caption: escape_rml(&caption),
                image: None,
                is_directory: false,
            },
            id,
        ));
    }
    items.sort_by(|a, b| a.0.caption.cmp(&b.0.caption));
    items
}

fn feature_defs(interface: &NativeInterfaceRef) -> Vec<(GridItem, i32)> {
    let defs = interface.feature_defs();
    let Ok(ids) = defs.get_feature_def_ids() else {
        return Vec::new();
    };
    let mut items = Vec::new();
    for id in ids {
        let Ok((info, true)) = defs.get_feature_def_by_id(id) else {
            continue;
        };
        let name = unsafe { std::ffi::CStr::from_ptr(info.name) }
            .to_string_lossy()
            .into_owned();
        if name.is_empty() {
            continue;
        }
        items.push((
            GridItem {
                id: name.clone(),
                caption: escape_rml(&name),
                image: None,
                is_directory: false,
            },
            id,
        ));
    }
    items.sort_by(|a, b| a.0.caption.cmp(&b.0.caption));
    items
}
