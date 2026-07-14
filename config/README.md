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
| `ui-rust-dev.json`                 | rust   | rust     | native UI + Dev tab, debug logging |

A config may also carry an `env` object; its entries are set in the engine's
environment (`ui-rust-dev.json` uses it for `SBC_DEV_PANEL` and `SBC_LOG_LEVEL`).

The old names (`rust-rmlui.json`, `mixed-rust-*`) named the *chonsole*, not the
UI, so `rust-rmlui` was the Lua UI. They are renamed above.

    just run config/ui-rust.json
