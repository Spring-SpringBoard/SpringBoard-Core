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
use std::collections::HashMap;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::panels::editor_base::{resolve_base, FieldSet, Layout};
use crate::sbc::panels::editors::def_filters::{DefTraits, FEATURE_TYPES, TERRAINS, UNIT_TYPES};
use crate::sbc::panels::field::{escape_rml, ChangeQueue, Field, FieldValue, InteractionQueue};
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

/// Cell size for the def grid. The thumbnails are rendered at 128px, so this is
/// still a downscale.
const ICON_SIZE: u32 = 96;

/// The grid filters. Changing one re-filters rather than re-arming placement.
const FILTER_FIELDS: &[&str] = &["typeFilter", "wreckFilter", "terrainFilter"];

/// Set-mode fields. The brush-mode ones are listed in `mode_fields`; the
/// inactive mode's are hidden, as Lua does with `SetInvisibleFields`.
const SET_FIELDS: &[&str] = &["amount"];

pub(crate) struct ObjectDefsView {
    kind: DefKind,
    grid: GridView,
    /// Every definition, unfiltered; the grid holds the filtered subset.
    all: Vec<GridItem>,
    /// Engine definition id by grid id, used by thumbnails and placement ghosting.
    def_ids: HashMap<String, i32>,
    /// What each definition is, for the Type/Wreck/Terrain filters.
    traits: HashMap<String, DefTraits>,
    search: String,
    search_element: Option<u64>,
    loaded: bool,
    search_dirty: bool,
    /// A definition was just clicked, or a setting changed with one selected;
    /// either re-arms placement.
    request_dirty: bool,

    fields: FieldSet,
    mode: PlaceMode,
    /// Whether the map click places an object. The Add/Brush buttons toggle it;
    /// with it off the map behaves normally and objects can be selected.
    placing: bool,
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
            // Bigger than the file/asset grids: these cells hold a rendered
            // model, not an icon, and at 64px a tree is unreadable.
            grid: GridView::new("object-defs-grid", ICON_SIZE),
            all: Vec::new(),
            def_ids: HashMap::new(),
            traits: HashMap::new(),
            search: String::new(),
            search_element: None,
            loaded: false,
            search_dirty: false,
            request_dirty: false,
            fields: FieldSet::new({
                let mut fields = placement_fields(vec![]);
                fields.extend(filter_fields(kind));
                fields
            }),
            mode: PlaceMode::Set,
            // Add is the mode the view opens in, and the button renders pressed.
            placing: true,
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

    /// A field committed. A filter re-filters the grid; anything else is a
    /// placement setting, so re-arm placement with it.
    ///
    /// Only if the value actually moved. RmlUi fires `change` for the values the
    /// editor writes back into the DOM, and re-arming on those dropped the user
    /// out of whatever they were doing -- a refresh mid-drag re-entered placement
    /// and started previewing ghosts over the object being moved.
    pub(crate) fn note_field_change(&mut self, name: &str, interface: &NativeInterfaceRef) {
        let base = resolve_base(name);
        let before = self.fields.value(base);
        self.fields.read(base, interface);
        if self.fields.value(base) == before {
            return;
        }
        if FILTER_FIELDS.contains(&base) {
            self.search_dirty = true;
        } else {
            self.request_dirty = true;
        }
    }

    pub(crate) fn generate_rml(&self) -> String {
        let mut h = String::from(r#"<div class="brush-actions">"#);
        for (mode, caption, image) in [
            (
                PlaceMode::Set,
                "Add",
                "LuaUI/images/scenedit/object-set-add.png",
            ),
            (
                PlaceMode::Brush,
                "Brush",
                "LuaUI/images/scenedit/object-brush-add.png",
            ),
        ] {
            // Pressed only while placement is actually armed: toggling the mode
            // off must not leave the button looking active.
            let pressed = if self.placing && mode == self.mode {
                " pressed"
            } else {
                ""
            };
            let id = if mode == PlaceMode::Set {
                "objectdef-mode-add"
            } else {
                "objectdef-mode-brush"
            };
            h.push_str(&format!(
                r#"<button id="{id}" class="brush-action{pressed}">
                    <img src="{image}" class="brush-action-icon"/>
                    <span class="brush-action-label">{caption}</span>
                </button>"#,
            ));
        }
        h.push_str("</div>");

        // The definitions come first -- filters, search, then the grid -- and the
        // placement settings sit *below* it, as they do in the Lua UI. Picking
        // what to place is the first thing you do; how to place it is the second.
        h.push_str(&self.fields.generate_rml(&[Layout::Section("Definitions")]));
        // The filters over the grid, as in Lua's MakeFilters: Units get Type +
        // Terrain, Features get Type + Wreck + Terrain.
        h.push_str(&self.fields.generate_rml(&match self.kind {
            DefKind::Unit => vec![Layout::Group(&["typeFilter", "terrainFilter"])],
            DefKind::Feature => vec![
                Layout::Group(&["typeFilter", "wreckFilter"]),
                Layout::Field("terrainFilter"),
            ],
        }));
        h.push_str(&format!(
            concat!(
                r#"<div class="field-row">"#,
                r#"<span class="field-label">Search:</span>"#,
                r#"<input type="text" id="object-defs-search" class="field-input"/>"#,
                r#"</div>{grid}"#,
            ),
            grid = self.grid.container_rml(),
        ));

        h.push_str(&self.fields.generate_rml(&[Layout::Field("team")]));
        // Only the active mode's fields.
        for name in self.mode_fields() {
            h.push_str(&self.fields.generate_rml(&[Layout::Field(name)]));
        }
        if self.mode == PlaceMode::Brush {
            h.push_str(&self.fields.generate_rml(&[
                Layout::Group(&["rotXMin", "rotXMax"]),
                Layout::Group(&["rotYMin", "rotYMax"]),
                Layout::Group(&["rotZMin", "rotZMax"]),
            ]));
        }
        h
    }

    fn mode_fields(&self) -> &'static [&'static str] {
        match self.mode {
            PlaceMode::Set => SET_FIELDS,
            // Rotation min/max fields render in grouped rows.
            PlaceMode::Brush => &["size", "spread", "noise"],
        }
    }

    /// Whether the name belongs to one of this view's fields. The search box is
    /// raw markup rather than a field, so it is the one thing that is not.
    pub(crate) fn is_field(&self, name: &str) -> bool {
        self.fields.get(resolve_base(name)).is_some()
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

        // Binding follows a rebuild, and a rebuild is a *new* grid container --
        // empty until it is filled again. Switching Add/Brush regenerates the
        // markup, so without this the definitions vanish the moment the mode
        // changes, and nothing can be placed.
        if self.loaded {
            self.apply_filter(interface, document)?;
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
        // The roster changing must not silently reset the grid's filters.
        let filters: Vec<(String, String)> = FILTER_FIELDS
            .iter()
            .filter(|name| self.fields.get(name).is_some())
            .map(|name| ((*name).to_string(), self.fields.text(name)))
            .collect();

        let captions: Vec<String> = self.teams.iter().map(|(_, c)| c.clone()).collect();
        let mut fields = placement_fields(captions);
        fields.extend(filter_fields(self.kind));
        self.fields = FieldSet::new(fields);

        for (name, value) in filters {
            self.fields.set(&name, FieldValue::Text(value));
        }
    }

    /// The filter choice, or its default when the field is not built yet.
    fn filter(&self, name: &str, default: &str) -> String {
        let value = self.fields.text(name);
        if value.is_empty() {
            return default.to_string();
        }
        value
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
            spread: self.fields.number("spread").max(1.0),
            noise: self.fields.number("noise").max(0.0),
            rot_min: [
                self.fields.number("rotXMin").to_radians(),
                self.fields.number("rotYMin").to_radians(),
                self.fields.number("rotZMin").to_radians(),
            ],
            rot_max: [
                self.fields.number("rotXMax").to_radians(),
                self.fields.number("rotYMax").to_radians(),
                self.fields.number("rotZMax").to_radians(),
            ],
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
            self.def_ids = loaded
                .iter()
                .map(|(item, def_id)| (item.id.clone(), *def_id))
                .collect();
            // Read once: a unit's traits come from its own def, a feature's from
            // the unit it is the wreck of (if any).
            self.traits = loaded
                .iter()
                .map(|(item, def_id)| {
                    let traits = match self.kind {
                        DefKind::Unit => DefTraits::of_unit(interface, *def_id),
                        DefKind::Feature => DefTraits::of_feature(interface, &item.id),
                    };
                    (item.id.clone(), traits)
                })
                .collect();
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
            // Picking a definition is a request to place it.
            self.placing = true;
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
                self.placing = true;
            } else {
                // Clicking the active button leaves placement, as Lua's action
                // buttons toggle. Without this there is no way out of Add mode:
                // every click on the map keeps placing, and objects can never be
                // selected or dragged.
                self.placing = !self.placing;
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

    /// The brush radius is shared with the placement state, so Shift+wheel can
    /// resize the brush mid-stroke and the field shows the new size.
    pub(crate) fn write_brush(&self, brush: &mut crate::sbc::states::BrushSettings) {
        brush.size = self.fields.number("size");
    }

    pub(crate) fn read_brush(
        &mut self,
        brush: &crate::sbc::states::BrushSettings,
        interface: &NativeInterfaceRef,
    ) {
        self.fields.set(
            "size",
            crate::sbc::panels::field::FieldValue::Number(brush.size),
        );
        let _ = self.fields.write_values(interface);
        // Re-arm placement so the stroke uses the size that is now on screen.
        self.request_dirty = true;
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
        if !self.placing {
            return Some(StateRequest::Default);
        }
        let Some(def) = self.grid.selected().map(str::to_string) else {
            return Some(StateRequest::Default);
        };
        let def_id = self.def_ids.get(&def).copied().unwrap_or(0);
        let config = self.config();
        Some(match self.kind {
            DefKind::Unit => StateRequest::AddUnit(def, def_id, config),
            DefKind::Feature => StateRequest::AddFeature(def, def_id, config),
        })
    }

    pub(crate) fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        self.fields.write_values(interface)
    }

    fn apply_filter(&mut self, interface: &NativeInterfaceRef, document: u64) -> Result<(), Error> {
        let terrain = self.filter("terrainFilter", TERRAINS[0]);
        let type_filter = self.filter(
            "typeFilter",
            match self.kind {
                DefKind::Unit => UNIT_TYPES[0],
                DefKind::Feature => FEATURE_TYPES[0],
            },
        );
        let wreck = self.filter("wreckFilter", UNIT_TYPES[0]);
        let kind = self.kind;

        let matches: Vec<GridItem> = self
            .all
            .iter()
            .filter(|item| {
                let searched = self.search.is_empty()
                    || item.caption.to_lowercase().contains(&self.search)
                    || item.id.to_lowercase().contains(&self.search);
                if !searched {
                    return false;
                }
                let traits = self.traits.get(&item.id).copied().unwrap_or_default();
                match kind {
                    DefKind::Unit => traits.passes_unit_filters(&type_filter, &terrain),
                    DefKind::Feature => {
                        traits.passes_feature_filters(&type_filter, &wreck, &terrain)
                    }
                }
            })
            .cloned()
            .collect();
        self.grid.set_items(matches);
        self.grid.render(interface, document)
    }
}

fn items(values: &[&str]) -> Vec<String> {
    values.iter().map(|value| (*value).to_string()).collect()
}

/// The grid's filters. Lua defaults every one of them to its first item, so the
/// grid opens showing non-building ground units / non-wreck features.
fn filter_fields(kind: DefKind) -> Vec<Box<dyn Field>> {
    let types = match kind {
        DefKind::Unit => UNIT_TYPES,
        DefKind::Feature => FEATURE_TYPES,
    };
    let mut fields: Vec<Box<dyn Field>> = vec![Box::new(ChoiceField::new(
        "typeFilter",
        "Type",
        items(types),
    ))];
    if kind == DefKind::Feature {
        // Which kind of unit the wreck came from.
        fields.push(Box::new(ChoiceField::new(
            "wreckFilter",
            "Wreck",
            items(UNIT_TYPES),
        )));
    }
    fields.push(Box::new(ChoiceField::new(
        "terrainFilter",
        "Terrain",
        items(TERRAINS),
    )));
    fields
}

fn placement_fields(teams: Vec<String>) -> Vec<Box<dyn Field>> {
    vec![
        Box::new(ChoiceField::new("team", "Team", teams)),
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
        // Lua's range and default. At the 0 it defaulted to, a brush held over
        // one spot dropped every object of every repeat dab on exactly the same
        // points -- the scatter is a fixed sunflower, and noise is what jitters it.
        Box::new(
            NumericField::new("noise", "Noise", 100.0)
                .min(1.0)
                .max(2000.0)
                .decimals(0),
        ),
        // Named as Lua names them ("Min rot x"), not pitch/yaw/roll: the two UIs
        // are meant to read the same.
        Box::new(
            NumericField::new("rotXMin", "Min rot x", 0.0)
                .min(-360.0)
                .max(360.0)
                .decimals(0),
        ),
        Box::new(
            NumericField::new("rotXMax", "Max rot x", 0.0)
                .min(-360.0)
                .max(360.0)
                .decimals(0),
        ),
        Box::new(
            NumericField::new("rotYMin", "Min rot y", -180.0)
                .min(-360.0)
                .max(360.0)
                .decimals(0),
        ),
        Box::new(
            NumericField::new("rotYMax", "Max rot y", 180.0)
                .min(-360.0)
                .max(360.0)
                .decimals(0),
        ),
        Box::new(
            NumericField::new("rotZMin", "Min rot z", 0.0)
                .min(-360.0)
                .max(360.0)
                .decimals(0),
        ),
        Box::new(
            NumericField::new("rotZMax", "Max rot z", 0.0)
                .min(-360.0)
                .max(360.0)
                .decimals(0),
        ),
    ]
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
            /// A field commit re-filters (a filter) or re-arms placement (a
            /// setting); either way its new value has to be read out of the DOM
            /// first. Only the search box is not a field.
            fn process_change(
                &mut self,
                name: &str,
                interface: &NativeInterfaceRef,
                _next: &mut u64,
            ) -> Vec<String> {
                if self.defs.is_field(name) {
                    self.defs.note_field_change(name, interface);
                } else {
                    self.defs.mark_search_dirty();
                }
                vec![]
            }
            fn process_drag_end(&mut self, _name: &str, _next: &mut u64) -> Vec<String> {
                vec![]
            }
            /// The object brush is a brush: Shift+wheel resizes it while placing,
            /// exactly as it does for the map brushes, and the `size` field has to
            /// follow the wheel (and lead it, when typed into).
            fn write_brush(&self, brush: &mut crate::sbc::states::BrushSettings) {
                self.defs.write_brush(brush);
            }
            fn read_brush(
                &mut self,
                brush: &crate::sbc::states::BrushSettings,
                interface: &NativeInterfaceRef,
            ) {
                self.defs.read_brush(brush, interface);
            }
            $crate::sb_delegate_editor_methods!(defs);
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
                tooltip: None,
                tooltip_markup: None,
            },
            id,
        ));
    }
    sort_by_caption(&mut items);
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
        let caption = ["displayName", "humanName", "name"]
            .into_iter()
            .find_map(|key| defs.get_feature_def_custom_param(id, key).ok().flatten())
            .filter(|value| !value.trim().is_empty())
            .or_else(|| cstr(info.description).filter(|value| !value.trim().is_empty()))
            .unwrap_or_else(|| name.clone());
        items.push((
            GridItem {
                id: name.clone(),
                // Dozens of defs share the caption "Tree"; the def name is the
                // only thing that tells them apart.
                tooltip: Some(escape_rml(&name)),
                caption: escape_rml(&caption),
                image: None,
                is_directory: false,
                tooltip_markup: None,
            },
            id,
        ));
    }
    sort_by_caption(&mut items);
    items
}

/// Alphabetical by what the user reads, ignoring case: a plain byte compare puts
/// every lowercase name after every capitalised one ("geovent" after "Tree").
///
/// The def name breaks ties. Many defs share a display name ("Tree"), and the
/// engine hands out def ids in no guaranteed order, so a tie left unbroken lets
/// the grid come out shuffled from one open to the next.
fn sort_by_caption(items: &mut [(GridItem, i32)]) {
    items.sort_by(|a, b| {
        a.0.caption
            .to_lowercase()
            .cmp(&b.0.caption.to_lowercase())
            .then_with(|| a.0.id.cmp(&b.0.id))
    });
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
