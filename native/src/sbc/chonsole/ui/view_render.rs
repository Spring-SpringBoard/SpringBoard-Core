//! Non-Rml drawing for the native Chonsole view.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::chonsole::framework::TextInput;

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
