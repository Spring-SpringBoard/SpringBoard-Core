//! Markup assembly shared by the editor runtime: section separators, grouped
//! rows, and identified rows for runtime visibility toggles.

/// Resolve a change-event name to its base field name. Colour sub-fields like
/// `"fogColor-r"` map to `"fogColor"`.
pub(crate) fn resolve_base(name: &str) -> &str {
    match name.rsplit_once('-') {
        Some((base, "r" | "g" | "b" | "hex")) => base,
        _ => name,
    }
}

/// Same markup as the section separators Lua's `Editor:AddControl` emits.
pub(crate) fn section_rml(caption: &str) -> String {
    format!(
        r#"<div class="field-section"><div class="field-section-label">{caption}</div><div class="field-section-line"></div></div>"#
    )
}

/// A row of fields laid out side by side, like Lua's `GroupField`.
///
/// Each field renders itself as a `field-row`, which is a block-level flex
/// container and so would take a whole line. Lua rewrites those to
/// `field-inline` when grouping; do the same.
pub(crate) fn group_rml(fields: &[String]) -> String {
    let inner: String = fields.iter().map(|f| grouped_field_rml(f, None)).collect();
    format!(r#"<div class="field-group">{inner}</div>"#)
}

pub(crate) fn identified_field_rml(field: String, name: &str) -> String {
    identified_field_with_row_attributes(field, name, "")
}

/// An identified field whose outer row follows an optional typed boolean.
/// Callers that have no condition keep the exact ordinary identified markup.
pub(crate) fn identified_field_visibility_rml(
    field: String,
    name: &str,
    visible: Option<&str>,
) -> String {
    match visible {
        Some(visible) => identified_field_when_rml(field, name, visible),
        None => identified_field_rml(field, name),
    }
}

/// An identified field whose outer row follows a typed boolean from the
/// surrounding RmlUi model. The field stays structurally present, so event
/// listeners bind once while `data-class-hidden` controls presentation.
pub(crate) fn identified_field_when_rml(field: String, name: &str, visible: &str) -> String {
    identified_field_with_row_attributes(
        field,
        name,
        &format!(r#" data-class-hidden="!{visible}""#),
    )
}

pub(crate) fn identified_group_rml(fields: &[(&str, String)]) -> String {
    identified_group_with_row_attributes(fields, "")
}

/// A grouped row whose individual field wrappers may follow distinct typed
/// booleans. This keeps grouped layouts declarative when only some controls
/// are meaningful in a given editor mode.
pub(crate) fn identified_group_visibility_rml(fields: &[(&str, String, Option<&str>)]) -> String {
    if fields.iter().all(|(_, _, visible)| visible.is_none()) {
        let ordinary = fields
            .iter()
            .map(|(name, field, _)| (*name, field.clone()))
            .collect::<Vec<_>>();
        return identified_group_rml(&ordinary);
    }
    let inner: String = fields
        .iter()
        .map(|(name, field, visible)| match visible {
            Some(visible) => grouped_field_with_row_attributes(
                field,
                Some(name),
                &format!(r#" data-class-hidden="!{visible}""#),
            ),
            None => grouped_field_with_row_attributes(field, Some(name), ""),
        })
        .collect();
    format!(r#"<div class="field-group">{inner}</div>"#)
}

/// A grouped identified row whose fields all follow one model boolean.
pub(crate) fn identified_group_when_rml(fields: &[(&str, String)], visible: &str) -> String {
    identified_group_with_row_attributes(fields, &format!(r#" data-class-hidden="!{visible}""#))
}

fn identified_field_with_row_attributes(field: String, name: &str, attributes: &str) -> String {
    field
        .replacen(
            r#"<div class="field-row field-boolean field-boolean-long">"#,
            &format!(
                r#"<div class="field-inline field-boolean field-boolean-long" id="row-{name}"{attributes}>"#
            ),
            1,
        )
        .replacen(
            r#"<div class="field-row field-boolean">"#,
            &format!(r#"<div class="field-row field-boolean" id="row-{name}"{attributes}>"#),
            1,
        )
        .replacen(
            r#"<div class="field-row">"#,
            &format!(r#"<div class="field-row" id="row-{name}"{attributes}>"#),
            1,
        )
}

fn identified_group_with_row_attributes(fields: &[(&str, String)], attributes: &str) -> String {
    let inner: String = fields
        .iter()
        .map(|(name, field)| grouped_field_with_row_attributes(field, Some(name), attributes))
        .collect();
    format!(r#"<div class="field-group">{inner}</div>"#)
}

fn grouped_field_rml(field: &str, id: Option<&str>) -> String {
    grouped_field_with_row_attributes(field, id, "")
}

fn grouped_field_with_row_attributes(field: &str, id: Option<&str>, attributes: &str) -> String {
    let target = match id {
        Some(id) => format!(r#"<div class="field-inline" id="row-{id}"{attributes}>"#),
        None => r#"<div class="field-inline">"#.to_string(),
    };
    field
        .replacen(
            r#"<div class="field-row field-boolean field-boolean-long">"#,
            &target.replacen(
                "field-inline",
                "field-inline field-boolean field-boolean-long",
                1,
            ),
            1,
        )
        .replacen(
            r#"<div class="field-row field-boolean">"#,
            &target.replacen("field-inline", "field-inline field-boolean", 1),
            1,
        )
        .replacen(r#"<div class="field-row">"#, &target, 1)
}
