//! The editor contract: a typed model (data), a layout over its field IDs
//! (data), and a behavior (refresh + apply). The runtime adapter runs
//! everything else.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel,
};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::panels::brush::BrushAction;
use crate::sbc::panels::field::Field;
use crate::sbc::panels::runtime::typed_fields::AssetGrid;
use crate::sbc::panels::tooltip::PanelTooltip;
use crate::sbc::project::EditorState;
use crate::sbc::states::StateRequest;

/// A field's binding into the shared brush. Both sync directions are one loop
/// in the runtime; editors declare the tag and never write brush code.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Brush {
    Size,
    Rotation,
    Strength,
    Height,
    Amount,
    Pattern,
    ApplyDirection,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Phase {
    /// A drag step or picker drag: the returned commands preview off-history.
    Preview,
    /// The undoable commit: Enter/blur/select, drag release, picker accept.
    Commit,
}

/// A user interaction, carrying the model's typed field ID.
#[derive(Debug, Clone, Copy)]
pub(crate) enum Event<Id> {
    Changed(Id, Phase),
}

/// What `watch` found this tick.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Watch {
    Unchanged,
    /// Re-run `refresh` and push values to the DOM.
    #[allow(dead_code)]
    Refresh,
    /// Also re-run `layout` and rebuild the markup.
    Rebuild,
}

/// What `apply` produced.
#[derive(Default)]
pub(crate) struct Outcome {
    pub commands: Vec<Box<dyn Command>>,
    pub state: Option<StateRequest>,
    pub rebuild: bool,
}

impl Outcome {
    pub(crate) fn commands(commands: Vec<Box<dyn Command>>) -> Self {
        Outcome {
            commands,
            ..Outcome::default()
        }
    }
}

/// One layout entry, over the model's field IDs.
pub(crate) enum Item<Id: 'static> {
    Field(Id),
    /// Fields laid out side by side.
    Row(&'static [Id]),
    Section(&'static str),
    /// An asset grid placed here (its value field contributes no row markup).
    Grid(Id),
    /// The behavior's brush-action strip.
    Actions,
    /// A field row with a stable `row-<name>` id, for runtime visibility.
    IdField(Id),
    /// An identified field whose row is hidden unless the named boolean in the
    /// surrounding data model is true.
    IdFieldWhen(Id, &'static str),
    /// A side-by-side row of identified fields.
    IdRow(&'static [Id]),
    /// Runtime-built variants for models whose layout is discovered at
    /// runtime (Properties builds rows from the selected object).
    OwnedRow(Vec<Id>),
    /// A runtime-built identified row whose fields are hidden unless the named
    /// boolean in the surrounding data model is true.
    OwnedIdRowWhen(Vec<Id>, &'static str),
    OwnedSection(String),
    /// Markup for a custom widget the behavior binds and drives itself
    /// (`Behavior::bind` / `Behavior::tick`). Layout runs over the model, so
    /// state-dependent markup regenerates on rebuild.
    Custom(String),
}

pub(crate) struct FieldRef<'a> {
    pub field: &'a dyn Field,
    pub brush: Option<Brush>,
}

pub(crate) struct FieldMut<'a> {
    pub field: &'a mut (dyn Field + 'a),
    pub brush: Option<Brush>,
}

/// A typed model: struct members for each field, exposed to the runtime
/// through these enumerations. `fields`/`fields_mut` are the one place a
/// model lists its members; everything else is keyed by `Id`.
pub(crate) trait EditorModel {
    type Id: Copy + Eq + 'static;

    fn fields(&self) -> Vec<FieldRef<'_>>;
    fn fields_mut(&mut self) -> Vec<FieldMut<'_>>;
    fn grids(&self) -> Vec<&AssetGrid> {
        vec![]
    }
    fn grids_mut(&mut self) -> Vec<&mut AssetGrid> {
        vec![]
    }

    /// The panel-owned tooltip surface for custom model controls. Standard
    /// fields and asset grids are wired by the runtime; models opt in only
    /// when they own another interactive control such as Texture's actions.
    fn set_tooltip_host(&mut self, _tooltip: PanelTooltip) {}

    /// Model-specific display state that is not an editable field. Bound here
    /// so the editor's complete model exists before its RML is parsed.
    fn prepare_data_model(&mut self, _model: &RmlDataModel<'static>) -> Result<(), Error> {
        Ok(())
    }

    /// DOM field name → typed ID. Events reach the behavior typed. Takes
    /// `&self` so models with runtime-generated fields can map too.
    fn id_of(&self, name: &str) -> Option<Self::Id>;
    fn name_of(&self, id: Self::Id) -> String;

    /// An optional boolean in the surrounding RmlUi model that controls this
    /// field row's visibility. The runtime owns the row markup, so editors
    /// declare only the state dependency instead of mutating DOM classes.
    fn field_visibility_binding(&self, _id: Self::Id) -> Option<&'static str> {
        None
    }
}

/// The editor's domain half. Everything mechanical lives in the runtime.
pub(crate) trait Behavior {
    type Model: EditorModel;

    /// Layout as data over the model's IDs. Re-called on rebuild.
    fn layout(&self, model: &Self::Model) -> Vec<Item<<Self::Model as EditorModel>::Id>>;

    /// Transfer state that belongs to a project, rather than to this ephemeral
    /// panel instance. The runtime owns the editor lifecycle, so behaviours do
    /// not need to know when tabs are replaced.
    fn load_editor_state(&mut self, model: &mut Self::Model, state: &EditorState) {
        let _ = (model, state);
    }

    fn save_editor_state(&self, model: &Self::Model, state: &mut EditorState) {
        let _ = (model, state);
    }

    /// World → model. Runs on open, undo/redo, watch hit.
    fn refresh(
        &mut self,
        model: &mut Self::Model,
        engine: &NativeInterfaceRef,
        models: &mut Models,
    );

    /// A field changed; return commands / state request / rebuild.
    fn apply(
        &mut self,
        event: Event<<Self::Model as EditorModel>::Id>,
        model: &mut Self::Model,
        engine: &NativeInterfaceRef,
    ) -> Outcome {
        let _ = (event, model, engine);
        Outcome::default()
    }

    /// Cheap per-tick check for views following external state.
    fn watch(&mut self, model: &mut Self::Model, models: &mut Models) -> Watch {
        let _ = (model, models);
        Watch::Unchanged
    }

    /// The brush-action strip, placed by `Item::Actions`.
    fn actions(&self) -> Option<&'static [BrushAction]> {
        None
    }

    /// Insert markup that lives outside the editor body (normally a modal).
    /// This runs before field binding, so fields in that markup use the exact
    /// same single binding pass as fields in the editor body.
    fn mount(
        &mut self,
        model: &mut Self::Model,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Result<(), spring_native::prelude::Error> {
        let _ = (model, interface, document);
        Ok(())
    }

    /// Bind the behavior's `Item::Custom` widgets. Runs after fields and grids.
    fn bind(
        &mut self,
        model: &mut Self::Model,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &crate::sbc::panels::field::ChangeQueue,
        interactions: &crate::sbc::panels::field::InteractionQueue,
    ) -> Result<(), spring_native::prelude::Error> {
        let _ = (model, interface, document, changes, interactions);
        Ok(())
    }

    /// Release data models owned by custom widgets before this editor is
    /// discarded. Standard asset grids are handled by the runtime itself.
    fn release_bindings(
        &mut self,
        model: &mut Self::Model,
        interface: &NativeInterfaceRef,
    ) -> Result<(), spring_native::prelude::Error> {
        let _ = (model, interface);
        Ok(())
    }

    /// Per-tick work for custom widgets, outside the RmlUi event dispatch.
    fn tick(
        &mut self,
        model: &mut Self::Model,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Outcome {
        let _ = (model, interface, document);
        Outcome::default()
    }

    /// The editing state to enter, recomputed when something re-armed it.
    /// Drained after `Outcome::state` and the action strip.
    fn state_request(&mut self, model: &mut Self::Model) -> Option<StateRequest> {
        let _ = model;
        None
    }

    /// The shared editing state left this editor (normally Escape).
    fn state_cleared(
        &mut self,
        model: &mut Self::Model,
        interface: &NativeInterfaceRef,
        document: u64,
    ) {
        let _ = (model, interface, document);
    }

    /// A state changed the shared brush and the fields followed (wheel resize,
    /// picked height).
    fn brush_read(&mut self, model: &mut Self::Model, brush: &crate::sbc::states::BrushSettings) {
        let _ = (model, brush);
    }

    /// Brush state the field tags cannot express (the texture brush carries a
    /// whole material). Runs after the tag loop, both on every sync.
    fn brush_write(&self, model: &Self::Model, brush: &mut crate::sbc::states::BrushSettings) {
        let _ = (model, brush);
    }

    /// Draw-thread work (rendering def thumbnails to textures).
    fn draw(&mut self, model: &mut Self::Model, interface: &NativeInterfaceRef) {
        let _ = (model, interface);
    }

    /// A field's value moved during a drag step, before any commit — for
    /// coupled fields that must follow each other on screen (the linked
    /// collision scales).
    fn dragged(
        &mut self,
        model: &mut Self::Model,
        id: <Self::Model as EditorModel>::Id,
        engine: &NativeInterfaceRef,
    ) {
        let _ = (model, id, engine);
    }

    /// Whether this editor currently owns a modal rendered outside the panel.
    fn modal_open(&self, model: &Self::Model) -> bool {
        let _ = model;
        false
    }
}
