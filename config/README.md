# Run configurations

`ui` picks which of the three independent implementations builds the editor UI.
Exactly one does; the other two build nothing.

| config                             | ui     | chonsole | what you see                       |
|------------------------------------|--------|----------|------------------------------------|
| `ui-chili.json`                    | chili  | lua      | the original Chili UI              |
| `ui-rmlui.json`                    | rmlui  | lua      | the Lua RmlUi UI                   |
| `ui-rust.json`                     | rust   | rust     | the native (Rust) UI               |
| `ui-chili-native-chonsole.json`    | chili  | rust     | Chili UI, native console           |
| `ui-rmlui-native-chonsole.json`    | rmlui  | rust     | Lua RmlUi UI, native console       |

The old names (`rust-rmlui.json`, `mixed-rust-*`) named the *chonsole*, not the
UI, so `rust-rmlui` was the Lua UI. They are renamed above.

    just run config/ui-rust.json
