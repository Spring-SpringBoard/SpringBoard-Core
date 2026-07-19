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
    field
        .replacen(
            r#"<div class="field-row field-boolean field-boolean-long">"#,
            &format!(
                r#"<div class="field-inline field-boolean field-boolean-long" id="row-{name}">"#
            ),
            1,
        )
        .replacen(
            r#"<div class="field-row field-boolean">"#,
            &format!(r#"<div class="field-row field-boolean" id="row-{name}">"#),
            1,
        )
        .replacen(
            r#"<div class="field-row">"#,
            &format!(r#"<div class="field-row" id="row-{name}">"#),
            1,
        )
}

pub(crate) fn identified_group_rml(fields: &[(&str, String)]) -> String {
    let inner: String = fields
        .iter()
        .map(|(name, field)| grouped_field_rml(field, Some(name)))
        .collect();
    format!(r#"<div class="field-group">{inner}</div>"#)
}

fn grouped_field_rml(field: &str, id: Option<&str>) -> String {
    let target = match id {
        Some(id) => format!(r#"<div class="field-inline" id="row-{id}">"#),
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
