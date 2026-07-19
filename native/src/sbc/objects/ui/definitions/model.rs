use std::cell::RefCell;
use std::collections::HashMap;
use std::rc::Rc;

use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::objects::ui::filters::{DefTraits, FEATURE_TYPES, TERRAINS, UNIT_TYPES};
use crate::sbc::panels::grid::{GridItem, GridView};
use crate::sbc::panels::runtime::{
    Brush, DynChoice, DynChoiceDef, EditorModel, FieldMut, FieldRef, Num, NumDef, StrChoice,
    StrChoiceDef,
};
use crate::sbc::panels::thumbnails::ThumbnailRenderer;
use crate::sbc::states::PlacementConfig;
use crate::sbc::teams::TeamManager;

/// Which definitions a view lists.
#[derive(Clone, Copy, PartialEq, Eq)]
pub(crate) enum DefKind {
    Unit,
    Feature,
}

/// Placement mode, chosen by the two buttons. Ports Lua's Add / Brush.
#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum PlaceMode {
    Set,
    Brush,
}

/// Cell size for the def grid. The thumbnails are rendered at 128px, so this is
/// still a downscale.
const ICON_SIZE: u32 = 96;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ObjectField {
    Team,
    Amount,
    Size,
    Spread,
    Noise,
    RotXMin,
    RotXMax,
    RotYMin,
    RotYMax,
    RotZMin,
    RotZMax,
    TypeFilter,
    WreckFilter,
    TerrainFilter,
    /// The search box: custom markup, no field row, still an event source.
    Search,
}

static TEAM: DynChoiceDef = DynChoiceDef {
    name: "team",
    label: "Team",
    brush: None,
};

static AMOUNT: NumDef = NumDef {
    name: "amount",
    label: "Amount",
    default: 1.0,
    min: Some(1.0),
    max: Some(100.0),
    decimals: Some(0),
    ..NumDef::BASE
}
.checked();

static SIZE: NumDef = NumDef {
    name: "size",
    label: "Size",
    default: 100.0,
    min: Some(10.0),
    max: Some(5000.0),
    decimals: Some(0),
    brush: Some(Brush::Size),
    ..NumDef::BASE
}
.checked();

static SPREAD: NumDef = NumDef {
    name: "spread",
    label: "Spread",
    default: 100.0,
    min: Some(1.0),
    max: Some(500.0),
    decimals: Some(0),
    ..NumDef::BASE
}
.checked();

// Lua's range and default. At the 0 it defaulted to, a brush held over one
// spot dropped every object of every repeat dab on exactly the same points --
// the scatter is a fixed sunflower, and noise is what jitters it.
static NOISE: NumDef = NumDef {
    name: "noise",
    label: "Noise",
    default: 100.0,
    min: Some(1.0),
    max: Some(2000.0),
    decimals: Some(0),
    ..NumDef::BASE
}
.checked();

// Named as Lua names them ("Min rot x"), not pitch/yaw/roll: the two UIs are
// meant to read the same.
static ROT_DEFS: [NumDef; 6] = [
    rot_def("rotXMin", "Min rot x", 0.0),
    rot_def("rotXMax", "Max rot x", 0.0),
    rot_def("rotYMin", "Min rot y", -180.0),
    rot_def("rotYMax", "Max rot y", 180.0),
    rot_def("rotZMin", "Min rot z", 0.0),
    rot_def("rotZMax", "Max rot z", 0.0),
];

const fn rot_def(name: &'static str, label: &'static str, default: f32) -> NumDef {
    NumDef {
        name,
        label,
        default,
        min: Some(-360.0),
        max: Some(360.0),
        decimals: Some(0),
        ..NumDef::BASE
    }
    .checked()
}

// The grid's filters. Lua defaults every one of them to its first item, so the
// grid opens showing non-building ground units / non-wreck features.
static UNIT_TYPE_FILTER: StrChoiceDef = StrChoiceDef {
    name: "typeFilter",
    label: "Type",
    items: UNIT_TYPES,
    brush: None,
};

static FEATURE_TYPE_FILTER: StrChoiceDef = StrChoiceDef {
    name: "typeFilter",
    label: "Type",
    items: FEATURE_TYPES,
    brush: None,
};

/// Which kind of unit the wreck came from.
static WRECK_FILTER: StrChoiceDef = StrChoiceDef {
    name: "wreckFilter",
    label: "Wreck",
    items: UNIT_TYPES,
    brush: None,
};

static TERRAIN_FILTER: StrChoiceDef = StrChoiceDef {
    name: "terrainFilter",
    label: "Terrain",
    items: TERRAINS,
    brush: None,
};

pub(crate) struct ObjectDefsModel {
    pub(super) kind: DefKind,
    team: DynChoice,
    amount: Num,
    size: Num,
    spread: Num,
    noise: Num,
    rot: Vec<Num>,
    type_filter: StrChoice,
    wreck_filter: Option<StrChoice>,
    terrain_filter: StrChoice,

    pub(super) grid: GridView,
    /// Every definition, unfiltered; the grid holds the filtered subset.
    pub(super) all: Vec<GridItem>,
    /// Engine definition id by grid id, used by thumbnails and placement ghosting.
    pub(super) def_ids: HashMap<String, i32>,
    /// What each definition is, for the Type/Wreck/Terrain filters.
    pub(super) traits: HashMap<String, DefTraits>,
    pub(super) search: String,
    pub(super) search_element: Option<u64>,
    pub(super) loaded: bool,
    pub(super) search_dirty: bool,
    /// A definition was just clicked, or a setting changed with one selected;
    /// either re-arms placement.
    pub(super) request_dirty: bool,
    pub(super) mode: PlaceMode,
    /// Whether the map click places an object. Add/Brush choose a placement
    /// mode; Escape (or a tab/editor change) returns the map to normal
    /// selection, never a second click on the active action.
    pub(super) placing: bool,
    pub(super) mode_clicks: Rc<RefCell<Vec<PlaceMode>>>,
    /// Team captions in the choice, paired with their ids.
    teams: Vec<(i32, String)>,
    teams_revision: usize,
    /// The team roster or mode changed, so the markup must be regenerated.
    pub(super) needs_rebuild: bool,
    /// Renders each def's model into a texture for its grid cell.
    pub(super) thumbnails: ThumbnailRenderer,
}

impl ObjectDefsModel {
    pub(crate) fn new(kind: DefKind) -> Self {
        ObjectDefsModel {
            kind,
            team: DynChoice::of(&TEAM),
            amount: Num::of(&AMOUNT),
            size: Num::of(&SIZE),
            spread: Num::of(&SPREAD),
            noise: Num::of(&NOISE),
            rot: ROT_DEFS.iter().map(Num::of).collect(),
            type_filter: StrChoice::of(match kind {
                DefKind::Unit => &UNIT_TYPE_FILTER,
                DefKind::Feature => &FEATURE_TYPE_FILTER,
            }),
            wreck_filter: (kind == DefKind::Feature).then(|| StrChoice::of(&WRECK_FILTER)),
            terrain_filter: StrChoice::of(&TERRAIN_FILTER),
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

    /// Populate the team choice from the model. Returns true if the roster
    /// changed and the markup must be regenerated (the choice's options did).
    pub(super) fn refresh_teams(&mut self, models: &mut Models) -> bool {
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
        let captions: Vec<String> = self.teams.iter().map(|(_, c)| c.clone()).collect();
        self.team.set_items(captions);
        self.needs_rebuild = true;
        true
    }

    /// The placement config from the current fields.
    pub(super) fn config(&self) -> PlacementConfig {
        let team = self
            .selected_team()
            .unwrap_or_else(|| self.teams.first().map(|(id, _)| *id).unwrap_or(0));
        PlacementConfig {
            team,
            brush: self.mode == PlaceMode::Brush,
            amount: self.amount.get().max(1.0) as u32,
            size: self.size.get(),
            spread: self.spread.get().max(1.0),
            noise: self.noise.get().max(0.0),
            rot_min: [
                self.rot[0].get().to_radians(),
                self.rot[2].get().to_radians(),
                self.rot[4].get().to_radians(),
            ],
            rot_max: [
                self.rot[1].get().to_radians(),
                self.rot[3].get().to_radians(),
                self.rot[5].get().to_radians(),
            ],
        }
    }

    pub(super) fn selected_team(&self) -> Option<i32> {
        let caption = self.team.get();
        self.teams
            .iter()
            .find(|(_, c)| c == caption)
            .map(|(id, _)| *id)
    }

    pub(super) fn apply_filter(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), Error> {
        let terrain = self.terrain_filter.get().to_string();
        let type_filter = self.type_filter.get().to_string();
        let wreck = self
            .wreck_filter
            .as_ref()
            .map(|f| f.get().to_string())
            .unwrap_or_else(|| UNIT_TYPES[0].to_string());
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

impl EditorModel for ObjectDefsModel {
    type Id = ObjectField;

    fn fields(&self) -> Vec<FieldRef<'_>> {
        let mut fields = vec![
            self.team.entry(),
            self.amount.entry(),
            self.size.entry(),
            self.spread.entry(),
            self.noise.entry(),
        ];
        fields.extend(self.rot.iter().map(Num::entry));
        fields.push(self.type_filter.entry());
        if let Some(wreck) = &self.wreck_filter {
            fields.push(wreck.entry());
        }
        fields.push(self.terrain_filter.entry());
        fields
    }

    fn fields_mut(&mut self) -> Vec<FieldMut<'_>> {
        let mut fields = vec![
            self.team.entry_mut(),
            self.amount.entry_mut(),
            self.size.entry_mut(),
            self.spread.entry_mut(),
            self.noise.entry_mut(),
        ];
        fields.extend(self.rot.iter_mut().map(Num::entry_mut));
        fields.push(self.type_filter.entry_mut());
        if let Some(wreck) = &mut self.wreck_filter {
            fields.push(wreck.entry_mut());
        }
        fields.push(self.terrain_filter.entry_mut());
        fields
    }

    fn id_of(&self, name: &str) -> Option<ObjectField> {
        Some(match name {
            "team" => ObjectField::Team,
            "amount" => ObjectField::Amount,
            "size" => ObjectField::Size,
            "spread" => ObjectField::Spread,
            "noise" => ObjectField::Noise,
            "rotXMin" => ObjectField::RotXMin,
            "rotXMax" => ObjectField::RotXMax,
            "rotYMin" => ObjectField::RotYMin,
            "rotYMax" => ObjectField::RotYMax,
            "rotZMin" => ObjectField::RotZMin,
            "rotZMax" => ObjectField::RotZMax,
            "typeFilter" => ObjectField::TypeFilter,
            "wreckFilter" => ObjectField::WreckFilter,
            "terrainFilter" => ObjectField::TerrainFilter,
            "search" => ObjectField::Search,
            _ => return None,
        })
    }

    fn name_of(&self, id: ObjectField) -> String {
        match id {
            ObjectField::Team => "team",
            ObjectField::Amount => "amount",
            ObjectField::Size => "size",
            ObjectField::Spread => "spread",
            ObjectField::Noise => "noise",
            ObjectField::RotXMin => "rotXMin",
            ObjectField::RotXMax => "rotXMax",
            ObjectField::RotYMin => "rotYMin",
            ObjectField::RotYMax => "rotYMax",
            ObjectField::RotZMin => "rotZMin",
            ObjectField::RotZMax => "rotZMax",
            ObjectField::TypeFilter => "typeFilter",
            ObjectField::WreckFilter => "wreckFilter",
            ObjectField::TerrainFilter => "terrainFilter",
            ObjectField::Search => "search",
        }
        .to_string()
    }
}
