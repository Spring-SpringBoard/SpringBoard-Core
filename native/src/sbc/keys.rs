use spring_native::prelude::NativeInterfaceRef;

#[derive(Copy, Clone, Default, Debug)]
#[allow(dead_code)]
pub(crate) struct KeyMods {
    pub alt: bool,
    pub ctrl: bool,
    pub meta: bool,
    pub shift: bool,
}

pub(crate) fn is_key(interface: &NativeInterfaceRef, key_code: i32, key_name: &str) -> bool {
    interface
        .input()
        .get_key_code(key_name)
        .is_ok_and(|expected| expected == key_code)
        || sdl2_key_code(key_name).is_some_and(|expected| expected == key_code)
}

fn sdl2_key_code(key_name: &str) -> Option<i32> {
    Some(match key_name {
        "f8" => 1_073_741_889,
        "f10" => 1_073_741_891,
        "numpad_enter" => 1_073_741_912,
        "up" => 1_073_741_906,
        "down" => 1_073_741_905,
        "right" => 1_073_741_903,
        "left" => 1_073_741_904,
        "home" => 1_073_741_898,
        "end" => 1_073_741_901,
        "pageup" => 1_073_741_899,
        "pagedown" => 1_073_741_902,
        "shift" => 1_073_742_049,
        "ctrl" => 1_073_742_048,
        "esc" => 27,
        _ => return None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn function_keys_follow_the_sdl_scancode_layout() {
        let f1 = 58 | (1 << 30);
        assert_eq!(sdl2_key_code("f8"), Some(f1 + 7));
        assert_eq!(sdl2_key_code("f10"), Some(f1 + 9));
    }

    #[test]
    fn non_printable_keys_have_sdl2_fallback_codes() {
        assert_eq!(sdl2_key_code("ctrl"), Some(1_073_742_048));
        assert_eq!(sdl2_key_code("left"), Some(1_073_741_904));
        assert_eq!(sdl2_key_code("home"), Some(1_073_741_898));
        assert_eq!(sdl2_key_code("pagedown"), Some(1_073_741_902));
    }

    #[test]
    fn printable_and_unknown_names_have_no_fallback() {
        assert_eq!(sdl2_key_code("a"), None);
        assert_eq!(sdl2_key_code("sysrq"), None);
    }
}
