//! The one implementation of editor plumbing. `Runtime<B>` renders a
//! behavior's layout, binds and drives its model's fields, syncs the brush
//! from field tags, and adapts everything to the manager-facing `Editor`
//! trait so old- and new-style editors coexist during the migration.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    RmlDataModel,
};

use crate::sbc::command_system::command::Command;
use crate::sbc::command_system::model::Models;
use crate::sbc::panels::brush::{non_empty, BrushActions};
use crate::sbc::panels::editor::Editor;
use crate::sbc::panels::editor_base::{
    group_rml, identified_field_visibility_rml, identified_field_when_rml,
    identified_group_visibility_rml, identified_group_when_rml, resolve_base, section_rml,
};
use crate::sbc::panels::field::{
    element_by_id, ChangeQueue, Field, FieldSpec, FieldValue, InteractionQueue,
};
use crate::sbc::panels::runtime::contract::Brush;
use crate::sbc::panels::runtime::contract::{
    Behavior, EditorModel, Event, Item, Outcome, Phase, Watch,
};
use crate::sbc::panels::tooltip::{PanelTooltip, TooltipContent};
use crate::sbc::project::EditorState;
use crate::sbc::states::{ApplyDir, BrushSettings, StateRequest};

pub(crate) struct Runtime<B: Behavior> {
    behavior: B,
    model: B::Model,
    actions: Option<BrushActions>,
    tooltip: Option<PanelTooltip>,
    /// Stashed on first contact; the old `Editor` trait omits it from some
    /// callbacks (`process_drag_end`) that the behavior still needs it in.
    engine: Option<NativeInterfaceRef>,
    /// Snapshot chosen by the editor slot. It is applied once, after the model
    /// has refreshed, without going through field-change dispatch.
    restore_brush: Option<BrushSettings>,
    pending_state: Option<StateRequest>,
    rebuild: bool,
    refresh: bool,
}

impl<B: Behavior> Runtime<B> {
    pub(crate) fn new(behavior: B, model: B::Model) -> Self {
        let actions = behavior.actions().map(BrushActions::new);
        Runtime {
            behavior,
            model,
            actions,
            tooltip: None,
            engine: None,
            restore_brush: None,
            pending_state: None,
            rebuild: false,
            refresh: false,
        }
    }

    pub(crate) fn model(&self) -> &B::Model {
        &self.model
    }

    pub(crate) fn model_mut(&mut self) -> &mut B::Model {
        &mut self.model
    }

    fn absorb(&mut self, outcome: Outcome) -> Vec<Box<dyn Command>> {
        if outcome.state.is_some() {
            self.pending_state = outcome.state;
        }
        if outcome.rebuild {
            self.rebuild = true;
            self.refresh = true;
        }
        outcome.commands
    }

    fn dispatch(&mut self, name: &str, phase: Phase) -> Vec<Box<dyn Command>> {
        let Some(id) = self.model.id_of(resolve_base(name)) else {
            return vec![];
        };
        let Some(engine) = self.engine else {
            return vec![];
        };
        let outcome = self
            .behavior
            .apply(Event::Changed(id, phase), &mut self.model, &engine);
        self.absorb(outcome)
    }

    fn field_rml(&self, name: &str) -> String {
        self.model
            .fields()
            .into_iter()
            .find(|entry| entry.field.name() == name)
            .map(|entry| entry.field.generate_rml())
            .unwrap_or_default()
    }

    fn field_mut(&mut self, name: &str) -> Option<&mut (dyn Field + '_)> {
        self.model
            .fields_mut()
            .into_iter()
            .find(|entry| entry.field.name() == name)
            .map(|entry| entry.field)
    }
}

impl<B: Behavior> Editor for Runtime<B> {
    fn load_editor_state(&mut self, state: &EditorState) {
        self.behavior.load_editor_state(&mut self.model, state);
    }

    fn save_editor_state(&self, state: &mut EditorState) {
        self.behavior.save_editor_state(&self.model, state);
    }

    fn load_brush_state(&mut self, brush: &BrushSettings) {
        self.restore_brush = Some(brush.clone());
    }

    fn generate_rml(&self) -> String {
        let mut html = String::new();
        for item in self.behavior.layout(&self.model) {
            match item {
                Item::Field(id) => html.push_str(&self.field_rml(&self.model.name_of(id))),
                Item::Row(ids) => {
                    let fields: Vec<String> = ids
                        .iter()
                        .map(|id| self.field_rml(&self.model.name_of(*id)))
                        .collect();
                    html.push_str(&group_rml(&fields));
                }
                Item::Section(caption) => html.push_str(&section_rml(caption)),
                Item::Grid(id) => {
                    let name = self.model.name_of(id);
                    if let Some(grid) = self
                        .model
                        .grids()
                        .into_iter()
                        .find(|grid| grid.name() == name)
                    {
                        html.push_str(&grid.container_rml());
                    }
                }
                Item::Actions => {
                    if let Some(actions) = &self.actions {
                        html.push_str(&actions.generate_rml());
                    }
                }
                Item::IdField(id) => {
                    let name = self.model.name_of(id);
                    html.push_str(&identified_field_visibility_rml(
                        self.field_rml(&name),
                        &name,
                        self.model.field_visibility_binding(id),
                    ));
                }
                Item::IdFieldWhen(id, visible) => {
                    let name = self.model.name_of(id);
                    html.push_str(&identified_field_when_rml(
                        self.field_rml(&name),
                        &name,
                        visible,
                    ));
                }
                Item::IdRow(ids) => {
                    let fields: Vec<(String, String, Option<&'static str>)> = ids
                        .iter()
                        .map(|id| {
                            let name = self.model.name_of(*id);
                            (
                                name.clone(),
                                self.field_rml(&name),
                                self.model.field_visibility_binding(*id),
                            )
                        })
                        .collect();
                    let refs: Vec<(&str, String, Option<&str>)> = fields
                        .iter()
                        .map(|(name, rml, visible)| (name.as_str(), rml.clone(), *visible))
                        .collect();
                    html.push_str(&identified_group_visibility_rml(&refs));
                }
                Item::OwnedRow(ids) => {
                    let fields: Vec<String> = ids
                        .iter()
                        .map(|id| self.field_rml(&self.model.name_of(*id)))
                        .collect();
                    html.push_str(&group_rml(&fields));
                }
                Item::OwnedIdRowWhen(ids, visible) => {
                    let fields: Vec<(String, String)> = ids
                        .iter()
                        .map(|id| {
                            let name = self.model.name_of(*id);
                            (name.clone(), self.field_rml(&name))
                        })
                        .collect();
                    let refs: Vec<(&str, String)> = fields
                        .iter()
                        .map(|(name, rml)| (name.as_str(), rml.clone()))
                        .collect();
                    html.push_str(&identified_group_when_rml(&refs, visible));
                }
                Item::OwnedSection(caption) => html.push_str(&section_rml(&caption)),
                Item::Custom(markup) => html.push_str(&markup),
            }
        }
        html
    }

    fn prepare_data_model(&mut self, model: &RmlDataModel<'static>) -> Result<(), Error> {
        self.model.prepare_data_model(model)?;
        if let Some(actions) = self.actions.as_mut() {
            actions.prepare_data_model(model)?;
        }
        for entry in self.model.fields_mut() {
            entry.field.prepare_data_model(model)?;
        }
        for grid in self.model.grids_mut() {
            grid.prepare_data_model(model)?;
        }
        Ok(())
    }

    fn release_bindings(&mut self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        for grid in self.model.grids_mut() {
            grid.release_bindings(interface)?;
        }
        self.behavior.release_bindings(&mut self.model, interface)?;
        Ok(())
    }

    fn bind_fields(
        &mut self,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        self.engine = Some(*interface);
        self.rebuild = false;
        let tooltip_host = self
            .tooltip
            .as_ref()
            .expect("editor slot binds the panel tooltip before fields")
            .clone();
        if let Some(actions) = self.actions.as_mut() {
            actions.bind(interface, document)?;
        }
        self.behavior.mount(&mut self.model, interface, document)?;
        for entry in self.model.fields_mut() {
            entry
                .field
                .bind(interface, document, changes, interactions)?;
            // Every field renders as `field-<name>`, so one place gives them
            // all hover text.
            let tooltip = entry.field.tooltip().map(str::to_string);
            if let Some(tooltip) = tooltip {
                let id = format!("field-{}", entry.field.name());
                if let Some(element) = element_by_id(interface, document, &id) {
                    tooltip_host.bind_to(interface, element, TooltipContent::text(tooltip))?;
                }
            }
        }
        for grid in self.model.grids_mut() {
            grid.bind(interface, document)?;
        }
        self.behavior
            .bind(&mut self.model, interface, document, changes, interactions)
    }

    fn set_tooltip_host(&mut self, tooltip: PanelTooltip) {
        self.tooltip = Some(tooltip.clone());
        if let Some(actions) = self.actions.as_mut() {
            actions.set_tooltip_host(tooltip.clone());
        }
        for grid in self.model.grids_mut() {
            grid.set_tooltip_host(tooltip.clone());
        }
    }

    fn write_field_values(&self, interface: &NativeInterfaceRef) -> Result<(), Error> {
        for entry in self.model.fields() {
            entry.field.write_to_dom(interface)?;
        }
        Ok(())
    }

    fn process_change(
        &mut self,
        name: &str,
        interface: &NativeInterfaceRef,
    ) -> Vec<Box<dyn Command>> {
        self.engine = Some(*interface);
        let base = resolve_base(name).to_string();
        // A colour sub-field (`-r`/`-g`/`-b`/`-hex`) commits that channel from
        // its own input; the whole-field DOM read cannot see it.
        if base != name {
            let sub = name.rsplit_once('-').map(|(_, s)| s.to_string());
            if let (Some(sub), Some(field)) = (sub, self.field_mut(&base)) {
                let before = field.value();
                if field.read_sub_field(&sub, interface).is_some() {
                    if field.value() == before {
                        return vec![];
                    }
                    return self.dispatch(&base, Phase::Commit);
                }
            }
        }
        // Suppress echoes: RmlUi fires `change` for the values the editor
        // writes back into the DOM. A commit that moved nothing must not reach
        // the behavior — re-arming placement on one dropped the user out of
        // whatever they were doing.
        if let Some(field) = self.field_mut(&base) {
            let before = field.value();
            let _ = field.read_from_dom(interface);
            if field.value() == before {
                return vec![];
            }
        }
        self.dispatch(&base, Phase::Commit)
    }

    fn process_drag_end(&mut self, name: &str, preview: bool) -> Vec<Box<dyn Command>> {
        let phase = if preview {
            Phase::Preview
        } else {
            Phase::Commit
        };
        self.dispatch(name, phase)
    }

    fn tick(&mut self, interface: &NativeInterfaceRef, document: u64) -> Vec<Box<dyn Command>> {
        self.engine = Some(*interface);
        if let Some(actions) = self.actions.as_mut() {
            actions.tick();
        }
        for grid in self.model.grids_mut() {
            grid.tick(interface, document);
        }
        let outcome = self.behavior.tick(&mut self.model, interface, document);
        self.absorb(outcome)
    }

    fn take_state_request(&mut self) -> Option<StateRequest> {
        self.pending_state
            .take()
            .or_else(|| self.actions.as_mut().and_then(BrushActions::take_request))
            .or_else(|| self.behavior.state_request(&mut self.model))
    }

    fn clear_state_selection(&mut self, interface: &NativeInterfaceRef, document: u64) {
        if let Some(actions) = self.actions.as_mut() {
            actions.clear();
        }
        self.behavior
            .state_cleared(&mut self.model, interface, document);
    }

    fn draw_thumbnails(&mut self, interface: &NativeInterfaceRef) {
        self.behavior.draw(&mut self.model, interface);
    }

    fn has_open_modal(&self) -> bool {
        self.behavior.modal_open(&self.model)
    }

    fn wants_refresh(&mut self, models: &mut Models) -> bool {
        match self.behavior.watch(&mut self.model, models) {
            Watch::Unchanged => std::mem::take(&mut self.refresh),
            Watch::Refresh => true,
            Watch::Rebuild => {
                self.rebuild = true;
                true
            }
        }
    }

    fn wants_rebuild(&self) -> bool {
        self.rebuild
    }

    fn write_brush(&self, brush: &mut BrushSettings) {
        for entry in self.model.fields() {
            let Some(tag) = entry.brush else { continue };
            match (tag, entry.field.value()) {
                (Brush::Size, FieldValue::Number(v)) => brush.size = v,
                (Brush::Rotation, FieldValue::Number(v)) => brush.rotation = v,
                (Brush::Strength, FieldValue::Number(v)) => brush.strength = v,
                (Brush::Height, FieldValue::Number(v)) => brush.height = v,
                (Brush::Amount, FieldValue::Number(v)) => brush.amount = v,
                (Brush::Pattern, FieldValue::Text(t)) => brush.pattern_texture = non_empty(t),
                (Brush::ApplyDirection, FieldValue::Text(t)) => {
                    brush.apply_dir = ApplyDir::from_caption(&t)
                }
                _ => {}
            }
        }
        self.behavior.brush_write(&self.model, brush);
    }

    /// A wheel resize or a right-clicked target height happened on the map;
    /// show it in the fields.
    fn read_brush(&mut self, brush: &BrushSettings, interface: &NativeInterfaceRef) {
        for entry in self.model.fields_mut() {
            let Some(tag) = entry.brush else { continue };
            let value = match tag {
                Brush::Size => FieldValue::Number(brush.size),
                Brush::Rotation => FieldValue::Number(brush.rotation),
                Brush::Strength => FieldValue::Number(brush.strength),
                Brush::Height => FieldValue::Number(brush.height),
                Brush::Amount => FieldValue::Number(brush.amount),
                Brush::Pattern => {
                    FieldValue::Text(brush.pattern_texture.clone().unwrap_or_default())
                }
                Brush::ApplyDirection => FieldValue::Text(brush.apply_dir.caption().to_string()),
            };
            entry.field.set_value(&value);
            let _ = entry.field.write_to_dom(interface);
        }
        self.behavior.brush_read(&mut self.model, brush);
    }

    fn refresh_from_engine(&mut self, interface: &NativeInterfaceRef, models: &mut Models) {
        self.engine = Some(*interface);
        self.behavior.refresh(&mut self.model, interface, models);
        if let Some(brush) = self.restore_brush.take() {
            self.read_brush(&brush, interface);
        }
    }

    fn drag_field(&mut self, name: &str, dx: f32, interface: &NativeInterfaceRef) -> bool {
        if let Some((base, sub)) = name.rsplit_once('-') {
            if matches!(sub, "r" | "g" | "b") {
                if let Some(field) = self.field_mut(base) {
                    field.prepare_drag(sub);
                    field.drag(dx, interface);
                    return true;
                }
            }
        }
        match self.field_mut(name) {
            Some(field) => {
                field.drag(dx, interface);
                if let Some(id) = self.model.id_of(resolve_base(name)) {
                    self.behavior.dragged(&mut self.model, id, interface);
                }
                true
            }
            None => false,
        }
    }

    fn drag_end_field(&mut self, name: &str, interface: &NativeInterfaceRef) -> bool {
        let base = resolve_base(name).to_string();
        match self.field_mut(&base) {
            Some(field) => {
                field.drag_end(interface);
                true
            }
            None => false,
        }
    }

    fn begin_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        if let Some((base, sub)) = name.rsplit_once('-') {
            if matches!(sub, "r" | "g" | "b") {
                if let Some(field) = self.field_mut(base) {
                    field.begin_sub_edit(sub, interface);
                    return;
                }
            }
        }
        if let Some(field) = self.field_mut(name) {
            field.begin_edit(interface);
        }
    }

    fn select_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        let base = resolve_base(name).to_string();
        if let Some(field) = self.field_mut(&base) {
            field.select_edit(interface);
        }
    }

    fn cancel_edit_field(&mut self, name: &str, interface: &NativeInterfaceRef) {
        let base = resolve_base(name).to_string();
        if let Some(field) = self.field_mut(&base) {
            field.end_edit(interface);
        }
    }

    fn field_value(&self, name: &str) -> FieldValue {
        let base = resolve_base(name);
        self.model
            .fields()
            .into_iter()
            .find(|entry| entry.field.name() == base)
            .map(|entry| entry.field.value())
            .unwrap_or(FieldValue::Text(String::new()))
    }

    fn set_field_value(&mut self, name: &str, value: FieldValue, interface: &NativeInterfaceRef) {
        let base = resolve_base(name).to_string();
        if let Some(field) = self.field_mut(&base) {
            field.set_value(&value);
        }
        let _ = self.write_field_values(interface);
    }

    fn field_specs(&self) -> Vec<FieldSpec> {
        self.model
            .fields()
            .into_iter()
            .map(|entry| FieldSpec {
                name: entry.field.name().to_string(),
                value: entry.field.value(),
                options: entry.field.options().map(<[String]>::to_vec),
            })
            .collect()
    }

    fn field_asset(&self, name: &str) -> Option<(String, Vec<String>)> {
        let base = resolve_base(name);
        self.model
            .fields()
            .into_iter()
            .find(|entry| entry.field.name() == base)
            .and_then(|entry| entry.field.asset_info())
    }
}
