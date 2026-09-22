use crate::sbc::panels::field::escape_rml;
use crate::sbc::panels::runtime::Item;

use super::catalogue::Named;
use super::model::{LabModel, Role, NONE};

pub(crate) fn layout(model: &LabModel) -> Vec<Item<usize>> {
    let Some(capabilities) = &model.capabilities else {
        return vec![Item::Custom(note(
            "Waiting for a renderer. Open a project with the game mounted; the renderer answers when it is up.",
        ))];
    };
    let id = |role: Role| model.id_of_role(&role);
    let mut items = vec![Item::OwnedSection(format!(
        "Renderer: {}",
        escape_rml(&status(model))
    ))];
    if let Some(reset) = id(Role::Reset) {
        items.push(Item::Field(reset));
    }
    let mut header = Vec::new();
    header.extend(id(Role::Solo));
    header.extend(id(Role::View));
    if !header.is_empty() {
        items.push(Item::OwnedRow(header));
    }
    if !capabilities.scenes.is_empty() {
        items.push(Item::OwnedSection("Test scene".to_string()));
        let mut row = Vec::new();
        row.extend(id(Role::Scene));
        row.extend(id(Role::LoadScene));
        items.push(Item::OwnedRow(row));
        let chosen = id(Role::Scene).map(|scene| model.value(scene));
        if let Some(crate::sbc::panels::field::FieldValue::Text(name)) = chosen {
            if let Some(scene) = capabilities.scenes.iter().find(|scene| scene.name == name) {
                items.push(Item::Custom(note(&scene.what)));
            }
        }
    }
    for category in categories(capabilities) {
        let mut fields: Vec<usize> = Vec::new();
        for (index, entry) in model.entries.iter().enumerate() {
            let Role::Control(control_id) = &entry.role else {
                continue;
            };
            if model
                .control(control_id)
                .is_some_and(|control| control.category == category.id)
            {
                fields.push(index);
            }
        }
        if fields.is_empty() {
            continue;
        }
        items.push(Item::OwnedSection(category.name.clone()));
        items.extend(fields.into_iter().map(Item::Field));
    }
    let overlays: Vec<usize> = model
        .entries
        .iter()
        .enumerate()
        .filter(|(_, entry)| matches!(entry.role, Role::Overlay(_)))
        .map(|(index, _)| index)
        .collect();
    if !overlays.is_empty() {
        items.push(Item::OwnedSection("Overlays".to_string()));
        items.extend(overlays.into_iter().map(Item::Field));
    }
    items.push(Item::OwnedSection("About".to_string()));
    if let Some(explain) = id(Role::Explain) {
        items.push(Item::Field(explain));
    }
    if let Some(control) = model
        .explaining
        .as_deref()
        .filter(|name| *name != NONE)
        .and_then(|name| model.control(name))
    {
        items.push(Item::Custom(explanation(
            &control.name,
            &control.id,
            &control.what,
            &control.how,
            &control.look,
        )));
    }
    items
}

/// The categories in the renderer's order, with any a control names that the renderer did
/// not list.
fn categories(capabilities: &super::catalogue::Capabilities) -> Vec<Named> {
    let mut categories = capabilities.categories.clone();
    for control in &capabilities.controls {
        if !categories.iter().any(|c| c.id == control.category) {
            categories.push(Named {
                id: control.category.clone(),
                name: control.category.clone(),
                what: String::new(),
            });
        }
    }
    categories
}

fn status(model: &LabModel) -> String {
    let state = &model.state;
    let mut parts = vec![format!(
        "{} lights, {} used",
        state.lights.candidates, state.lights.chosen
    )];
    if let Some(solo) = &state.solo {
        parts.push(format!("solo {solo}"));
    }
    if let Some(scene) = &state.scene {
        parts.push(format!("scene {scene}"));
    }
    parts.join(", ")
}

fn note(text: &str) -> String {
    format!(r#"<div class="render-lab-note">{}</div>"#, escape_rml(text))
}

fn explanation(name: &str, id: &str, what: &str, how: &str, look: &str) -> String {
    let mut out = format!(
        r#"<div class="render-lab-explain"><div class="render-lab-explain-title">{} <span class="render-lab-explain-id">{}</span></div>"#,
        escape_rml(name),
        escape_rml(id)
    );
    for (heading, text) in [
        ("What", what),
        ("How it is done", how),
        ("What to look for", look),
    ] {
        if text.is_empty() {
            continue;
        }
        out.push_str(&format!(
            r#"<div class="render-lab-explain-heading">{heading}</div><div class="render-lab-explain-text">{}</div>"#,
            escape_rml(text)
        ));
    }
    out.push_str("</div>");
    out
}
