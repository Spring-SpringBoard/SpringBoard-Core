use spring_native::prelude::{Error, NativeInterfaceRef};

use crate::sbc::command_system::model::Models;
use crate::sbc::objects::thumbnails::ThumbKind;
use crate::sbc::objects::ui::filters::DefTraits;
use crate::sbc::panels::controls::grid::GridItem;
use crate::sbc::panels::field::{escape_rml, ChangeQueue, CommitRequest, InteractionQueue};
use crate::sbc::panels::runtime::{Behavior, Event, Item, Outcome, Phase, Watch};
use crate::sbc::rml::element_by_id;
use crate::sbc::states::StateRequest;

use super::layout;
use super::model::{DefKind, ObjectDefsModel, ObjectField, PlaceMode};

pub(crate) struct ObjectDefsBehavior;

impl Behavior for ObjectDefsBehavior {
    type Model = ObjectDefsModel;

    fn layout(&self, model: &ObjectDefsModel) -> Vec<Item<ObjectField>> {
        layout::layout(model)
    }

    fn refresh(
        &mut self,
        model: &mut ObjectDefsModel,
        _engine: &NativeInterfaceRef,
        models: &mut Models,
    ) {
        model.refresh_teams(models);
    }

    /// The team roster and the mode buttons are the external state; a change
    /// to either regenerates the markup.
    fn watch(&mut self, model: &mut ObjectDefsModel, models: &mut Models) -> Watch {
        let teams_changed = model.refresh_teams(models);
        let pending = std::mem::take(&mut model.needs_rebuild);
        if teams_changed || pending {
            Watch::Rebuild
        } else {
            Watch::Unchanged
        }
    }

    /// A filter re-filters the grid; anything else is a placement setting, so
    /// re-arm placement with it. Echo commits never get here: the runtime
    /// suppresses value-preserving changes.
    fn apply(
        &mut self,
        event: Event<ObjectField>,
        model: &mut ObjectDefsModel,
        _engine: &NativeInterfaceRef,
    ) -> Outcome {
        let Event::Changed(id, phase) = event;
        if phase != Phase::Commit {
            return Outcome::default();
        }
        match id {
            ObjectField::Search
            | ObjectField::TypeFilter
            | ObjectField::WreckFilter
            | ObjectField::TerrainFilter => model.search_dirty = true,
            _ => model.request_dirty = true,
        }
        Outcome::default()
    }

    fn bind(
        &mut self,
        model: &mut ObjectDefsModel,
        interface: &NativeInterfaceRef,
        document: u64,
        changes: &ChangeQueue,
        _interactions: &InteractionQueue,
    ) -> Result<(), Error> {
        model.search_element = element_by_id(interface, document, "object-defs-search");
        if let Some(element) = model.search_element {
            let queue = changes.clone();
            interface
                .rml_ui()
                .element_add_event_listener(element, "change", false, move || {
                    queue.borrow_mut().push(CommitRequest {
                        field: "search".to_string(),
                        from_blur: false,
                        revert: false,
                    });
                })?;
        }

        for (id, mode) in [
            ("objectdef-mode-add", PlaceMode::Set),
            ("objectdef-mode-brush", PlaceMode::Brush),
        ] {
            if let Some(button) = element_by_id(interface, document, id) {
                let queue = model.mode_clicks.clone();
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
        if model.loaded {
            model.apply_filter(interface, document)?;
        }
        Ok(())
    }

    /// Load defs, handle search + grid + mode clicks; placement re-arming is
    /// picked up by `state_request`.
    fn tick(
        &mut self,
        model: &mut ObjectDefsModel,
        interface: &NativeInterfaceRef,
        document: u64,
    ) -> Outcome {
        if let Err(err) = tick_widgets(model, interface, document) {
            log::warn!("object defs tick: {err:?}");
        }
        Outcome::default()
    }

    /// The placement state to enter, if a definition is selected and something
    /// changed. Ports `ObjectDefsView:EnterState`.
    fn state_request(&mut self, model: &mut ObjectDefsModel) -> Option<StateRequest> {
        if !std::mem::take(&mut model.request_dirty) {
            return None;
        }
        if !model.placing {
            return Some(StateRequest::Default);
        }
        let Some(def) = model.grid.selected().map(str::to_string) else {
            return Some(StateRequest::Default);
        };
        let def_id = model.def_ids.get(&def).copied().unwrap_or(0);
        let config = model.config();
        Some(match model.kind {
            DefKind::Unit => StateRequest::AddUnit(def, def_id, config),
            DefKind::Feature => StateRequest::AddFeature(def, def_id, config),
        })
    }

    /// The shared editor state left placement (normally through Escape). Keep
    /// the action strip truthful: a mode is chosen only while it is armed.
    fn state_cleared(
        &mut self,
        model: &mut ObjectDefsModel,
        _interface: &NativeInterfaceRef,
        _document: u64,
    ) {
        if model.placing {
            model.placing = false;
            model.needs_rebuild = true;
        }
    }

    /// The brush radius is shared with the placement state, so Shift+wheel can
    /// resize the brush mid-stroke; re-arm placement so the stroke uses the
    /// size that is now on screen.
    fn brush_read(
        &mut self,
        model: &mut ObjectDefsModel,
        _brush: &crate::sbc::states::BrushSettings,
    ) {
        model.request_dirty = true;
    }

    /// Create/redraw the def thumbnails. Runs on the draw thread.
    fn draw(&mut self, model: &mut ObjectDefsModel, interface: &NativeInterfaceRef) {
        model.thumbnails.draw(interface);
    }
}

fn tick_widgets(
    model: &mut ObjectDefsModel,
    interface: &NativeInterfaceRef,
    document: u64,
) -> Result<(), Error> {
    if !model.loaded {
        let (loaded, thumb_kind) = match model.kind {
            DefKind::Unit => (unit_defs(interface), ThumbKind::Unit),
            DefKind::Feature => (feature_defs(interface), ThumbKind::Feature),
        };
        for (item, def_id) in &loaded {
            model.thumbnails.request(&item.id, *def_id, thumb_kind);
        }
        model.def_ids = loaded
            .iter()
            .map(|(item, def_id)| (item.id.clone(), *def_id))
            .collect();
        // Read once: a unit's traits come from its own def, a feature's from
        // the unit it is the wreck of (if any).
        model.traits = loaded
            .iter()
            .map(|(item, def_id)| {
                let traits = match model.kind {
                    DefKind::Unit => DefTraits::of_unit(interface, *def_id),
                    DefKind::Feature => DefTraits::of_feature(interface, &item.id),
                };
                (item.id.clone(), traits)
            })
            .collect();
        model.all = loaded.into_iter().map(|(item, _)| item).collect();
        model.loaded = true;
        model.apply_filter(interface, document)?;
    }

    // Thumbnails are created on the draw thread; when their names appear,
    // point each grid cell at its texture and re-render.
    if model.thumbnails.take_names_dirty() {
        let names: Vec<(String, Option<String>)> = model
            .all
            .iter()
            .filter(|item| item.image.is_none())
            .map(|item| {
                (
                    item.id.clone(),
                    model.thumbnails.texture_for(&item.id).map(str::to_string),
                )
            })
            .collect();
        for (id, texture) in names {
            if let Some(item) = model.all.iter_mut().find(|i| i.id == id) {
                item.image = texture;
            }
        }
        model.apply_filter(interface, document)?;
    }

    if model.search_dirty {
        model.search_dirty = false;
        if let Some(element) = model.search_element {
            if let Ok((Some(value), true)) =
                interface.rml_ui().element_get_attribute(element, "value")
            {
                model.search = value.to_lowercase();
            }
        }
        model.apply_filter(interface, document)?;
    }

    for id in model.grid.drain_clicks() {
        model.grid.set_selected(Some(&id));
        // Picking a definition is a request to place it.
        model.placing = true;
        model.request_dirty = true;
        model.grid.render(interface, document)?;
    }

    // Keep the thumbnails tinted for the chosen team.
    if let Some(team) = model.selected_team() {
        model.thumbnails.set_team(team);
    }

    let mode_change = model.mode_clicks.borrow_mut().drain(..).next_back();
    if let Some(mode) = mode_change {
        if mode != model.mode {
            model.mode = mode;
            model.needs_rebuild = true;
        }
        // Re-selecting the current action is deliberately a no-op from the
        // user's perspective, but re-arm its state in case Escape had returned
        // the map to selection while the panel stayed open.
        model.placing = true;
        model.request_dirty = true;
    }
    Ok(())
}

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
        let Ok(Some(info)) = defs.get_feature_def_info(id) else {
            continue;
        };
        let name = info.name;
        if name.is_empty() {
            continue;
        }
        let caption = ["displayName", "humanName", "name"]
            .into_iter()
            .find_map(|key| defs.get_feature_def_custom_param(id, key).ok().flatten())
            .filter(|value| !value.trim().is_empty())
            .or_else(|| (!info.description.trim().is_empty()).then_some(info.description))
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
