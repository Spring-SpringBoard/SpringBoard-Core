//! Stateless rendering for the native Chonsole view.

use spring_native::prelude::NativeInterfaceRef;

use super::text_input::TextInput;
use super::types::{ChonsoleLine, ChonsoleLineKind};
use super::view_suggestions::{escape_rml, SuggestionView};

pub(super) fn draw_texture_preview(interface: &NativeInterfaceRef, input: &TextInput) {
    let Some(texture) = input
        .value()
        .strip_prefix("/texture ")
        .and_then(|args| args.split_whitespace().next())
    else {
        return;
    };
    if !texture.starts_with('$') {
        return;
    }
    let gfx = interface.gfx();
    let Ok((width, height, _, _, _, _)) = gfx.texture_info(texture) else {
        return;
    };
    if width < 0 || height < 0 {
        return;
    }
    let _ = gfx.push_pop_matrix(|| {
        let _ = gfx.bind_texture(texture, 0, true);
        let _ = gfx.tex_rect(40.0, 180.0, 440.0, 580.0, 0.0, 0.0, 1.0, 1.0);
        let _ = gfx.bind_texture("", 0, false);
        let _ = gfx.begin_text(false);
        let _ = gfx.text(&format!("{width}x{height}"), 200.0, 165.0, 16.0, "o");
        let _ = gfx.end_text();
    });
}

pub(super) fn render_body(
    input: &TextInput,
    output: &[ChonsoleLine],
    suggestions: &SuggestionView,
) -> String {
    let rendered_suggestions = suggestions.render();
    let suggestions = if rendered_suggestions.is_empty() {
        String::new()
    } else {
        format!(
            r#"<div id="native-chonsole-suggestions" class="suggestions">{rendered_suggestions}</div><div id="native-chonsole-suggestion-details" class="suggestion-details">{}</div>"#,
            render_suggestion_details(suggestions.detail(None)),
        )
    };
    format!(
        r#"<div id="native-chonsole-lines" class="lines">{}</div>{}<div id="native-chonsole-input" class="input-row"><span class="prompt">&gt;</span>{}</div>"#,
        render_lines(output),
        suggestions,
        render_input(input),
    )
}

/// Render the full command description separately from its compact list row.
/// This strip has a fixed footprint, so selecting or hovering a command never
/// shifts the suggestion list or its scrollbar.
pub(super) fn render_suggestion_details(details: Option<(&str, &str)>) -> String {
    let Some((command, description)) = details else {
        return String::new();
    };
    format!(
        r#"<span class="suggestion-details-command">{}</span><span class="suggestion-details-text"> {}</span>"#,
        escape_rml(command),
        escape_rml(description),
    )
}

fn render_lines(output: &[ChonsoleLine]) -> String {
    output
        .iter()
        .map(|line| {
            let class = match line.kind {
                ChonsoleLineKind::Input => "line input-line",
                ChonsoleLineKind::Output => "line output-line",
            };
            format!(r#"<div class="{class}">{}</div>"#, escape_rml(&line.text))
        })
        .collect::<Vec<_>>()
        .join("")
}

fn render_input(input: &TextInput) -> String {
    let value = input.value();
    match input.selection_range() {
        Some((start, end)) if input.cursor() == start => format!(
            r#"<span class="input">{}</span><span class="cursor">&nbsp;</span><span class="input selection">{}</span><span class="input">{}</span>"#,
            escape_rml(&value[..start]),
            escape_rml(&value[start..end]),
            escape_rml(&value[end..]),
        ),
        Some((start, end)) => format!(
            r#"<span class="input">{}</span><span class="input selection">{}</span><span class="cursor">&nbsp;</span><span class="input">{}</span>"#,
            escape_rml(&value[..start]),
            escape_rml(&value[start..end]),
            escape_rml(&value[end..]),
        ),
        None => {
            let (before, after) = value.split_at(input.cursor());
            format!(
                r#"<span class="input">{}</span><span class="cursor">&nbsp;</span><span class="input">{}</span>"#,
                escape_rml(before),
                escape_rml(after),
            )
        }
    }
}
