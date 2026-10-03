use crate::sbc::panels::field::escape_rml;
use crate::sbc::panels::runtime::Item;

use super::model::{
    LabModel, Role, NONE, SCENE_NOTE_BINDING, SCENE_NOTE_SHOWN_BINDING, STATUS_BINDING,
};

pub(crate) fn layout(model: &LabModel) -> Vec<Item<usize>> {
    let Some(capabilities) = &model.capabilities else {
        return vec![Item::Custom(note(
            "Waiting for a renderer. Open a project with the game mounted; the renderer answers when it is up.",
        ))];
    };
    let id = |role: Role| model.id_of_role(&role);
    // Bound, not written in: the line follows every reply, and the markup is only rebuilt
    // when the controls themselves change.
    let mut items = vec![Item::OwnedSection(format!(
        "Renderer: {{{{ {STATUS_BINDING} }}}}"
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
    let scenes = capabilities.scenes_in(model.panel);
    if !scenes.is_empty() {
        items.push(Item::OwnedSection("Test scene".to_string()));
        let mut row = Vec::new();
        row.extend(id(Role::Scene));
        row.extend(id(Role::LoadScene));
        items.push(Item::OwnedRow(row));
        items.push(Item::Custom(format!(
            r#"<div class="render-lab-note" data-class-hidden="!{SCENE_NOTE_SHOWN_BINDING}">{{{{ {SCENE_NOTE_BINDING} }}}}</div>"#
        )));
    }
    for category in capabilities.categories_in(model.panel) {
        if category.hidden {
            continue;
        }
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
        // Buttons next to each other share a row.
        let is_button = |index: usize| match &model.entries[index].role {
            Role::Control(id) => model.control(id).is_some_and(|c| c.is_button()),
            _ => false,
        };
        let mut buttons = Vec::new();
        for field in fields {
            if is_button(field) {
                buttons.push(field);
                continue;
            }
            if !buttons.is_empty() {
                items.push(Item::OwnedRow(std::mem::take(&mut buttons)));
            }
            items.push(Item::Field(field));
        }
        if !buttons.is_empty() {
            items.push(Item::OwnedRow(buttons));
        }
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
