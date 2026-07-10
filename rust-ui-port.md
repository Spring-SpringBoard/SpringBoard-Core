# SpringBoard UI → Rust (native RmlUi)

Port the editor UI to the native Rust plugin, rendering through the engine's
RmlUi. The result must be functionally identical to, and completely independent
of, the two Lua UIs.

## The mandate

**Port the Lua UIs (Chili, and notably RmlUi) to Rust, fully. Do not stop until
it is all done.**

- **No quick hacks.** If the engine is missing something, add the binding
  properly, with a test that fails without it. `ElementGetRect` is the model:
  header + impl + vtable entry + `test/engine/Rml/TestNativeElementRect.cpp`.
- **Fix crashes properly**, at the cause, never by working around them.
- **Code must be properly modular.** One file per view; shared plumbing in
  `editor_base.rs`; nothing view-specific in the shell.
- **Then actually check everything.** Do a careful visual inspection yourself,
  and verify the *behaviour* of every control type:
  numbers, text, checkboxes, colour pickers, material pickers,
  unit/feature pickers, grids, dialogs.
- **Every tab must work, and every tab must be tested**: Objects, Map, Env, Misc.

A control is not "done" because it renders. It is done when a test asserts the
command it emits, and a human-inspected reference image shows it.

## Ground rules

1. **Scope is Rust + RmlUi.** Do not work on the Lua UIs. Open them only to
   compare behaviour or read a value, never to "fix" them as part of this task.
2. **The three UIs are independent.** `port_flags.json`'s `ui` is one of
   `chili` | `rmlui` | `rust`. Exactly one builds a UI; the other two build
   nothing. The gadget publishes it as the `sb_ui` game rules param.
3. **Modularity is the point.** Each view is one self-registering file under
   `native/src/sbc/panels/editors/`. Merging a view into `rust-stable` must mean
   cherry-picking that file plus its `mod` line — nothing else in the shell
   changes. Merge order is roughly: Env → Objects (units/features) → Map/Settings.

## Testing rules

The old e2e suite was worthless as a functional check: it asserted "no Lua error
and no ASAN crash", so it passed while clicking on features that were not on
screen, and while clicking through a colour-picker modal that had opened
somewhere else entirely. A green run meant "did not crash", nothing more.

Every test for this port must do both of the following.

### 1. Assert on deterministic output, not on the absence of a crash

A control that does something must *prove* it did that thing:

- A field edit emits a specific command envelope, with the expected values, into
  `commands.jsonl`.
- A query reads back the value the engine actually holds.
- A button that opens a view puts a known element into the DOM.

If a test cannot state what output it expects, it is not a test.

### 2. Golden screenshots, reviewed by a human, diffed by the machine

- Screenshots are checked in under `tools/e2e/golden/<case>/<name>.png` and
  treated as source code.
- A run compares each screenshot to its golden and fails on **any** pixel
  difference. No tolerance.
- A new or intentionally changed golden must be *looked at* before it is
  committed. `just test-e2e <target> --update-golden` writes it; the diff shows
  up in review like any other change.
- For this to work the frame must be deterministic: the game is paused, the
  camera is fixed, and the cursor is parked off the panel before each capture.

Without the pixel diff, a screenshot test only catches crashes, which the log
already catches.

## Layout

```
native/src/sbc/panels/
  registry.rs     EditorSpec + Tab; editors self-register via `inventory`
  view.rs         RmlUi context/document, tab bar, editor strip, content host
  manager.rs      shell events, active editor, command envelopes
  input.rs        mouse/keyboard, drag state machine
  field.rs        Field trait, DOM helpers, event queues
  fields/         numeric, choice, color
  editors/        one file per view; each submits an EditorSpec
    env_lighting.rs
```

## Done

- Shell: right-hand panel (500dp) matching the Lua geometry, tab bar
  (Objects/Map/Env/Misc), registry-driven editor button strip, content host.
- `ui: "rust"` flag; Lua builds no UI in that mode (`sb_ui` game rules param).
- Env → Lighting ported and rendering live engine values.

**Engine gotcha found:** the engine renders every RmlUi context itself in
`RmlGui::RenderFrame`, between `BeginFrame` and `PresentFrame`. A plugin calling
`context_render` from its own `draw_screen` submits geometry outside that frame,
where it is silently dropped — the panel laid out correctly (hit tests passed)
but drew nothing. `PanelView::draw` is a no-op. The native chonsole still calls
`context_render`; its RmlUi content has therefore never actually been visible
(it draws its text through `interface.gfx()`), and should be cleaned up.

## Running it

```
just run config/ui-rust.json                  # native UI
python3 tools/e2e/ui_driver.py all --tag ui:rust
python3 tools/e2e/ui_driver.py native-panel --update-golden   # re-capture refs
python3 tools/e2e/approve_goldens.py native-panel-rust        # human OK
```

## Control-type checklist

Each must render, behave, emit the right command, and have a reference image.

| control | native status |
|---|---|
| numeric (click-to-edit) | done — commits once, on Enter or blur |
| numeric (drag)          | done — polled cursor; engine reports no mouse_move |
| choice / select         | renders; **behaviour untested** |
| colour picker           | done — modal, SV+hue drag, OK/Cancel |
| checkbox / boolean      | **not ported** |
| text / string           | **not ported** |
| asset / material picker | **not ported** |
| unit / feature picker   | **not ported** (grid + RTT thumbnails) |
| grid view               | **not ported** |
| dialogs                 | picker only |

## TODO

- [ ] Env → Water (many fields, needs BooleanField + AssetField).
- [ ] Env → Sky's skybox texture field (needs an asset picker).
- [ ] Objects → Units, Objects → Features (grid view + 3D RTT thumbnails via
      `<texture src>`).
- [ ] Objects → Properties, Collision.
- [ ] Map → Settings, then the remaining Map views.
- [ ] Toolbar action buttons (new/open/save/export); currently `#action-bar` is
      an empty placeholder.
- [ ] Undo/redo refresh path: `on_history_events` sets `needs_refresh`, but only
      the open editor is refreshed. Verify against an undo of a lighting change.
- [ ] Native chonsole: remove its dead `context_render` call.
- [ ] Visual parity gaps against Lua RmlUi, visible in the reference images:
      the `shadowMode` select is narrower and sits high; the toolbar action bar
      is an empty placeholder, so content starts ~30px higher.
- [ ] Field widths: Lua sizes numeric/colour buttons per-field (`width = 140`);
      the native fields hardcode 78/140.

## Engine notes

- The engine renders every RmlUi context in `RmlGui::RenderFrame`, between
  `BeginFrame` and `PresentFrame`. A plugin must **not** call `context_render`.
- The engine also feeds keyboard/text input straight to its RmlUi contexts, so a
  plugin never sees those keys through its own `key_press` call-in. Listen on
  the element and read `key_identifier` off `event_get_current()`.
- RmlUi fires `change` on a text input per keystroke. Commit on Enter or blur.
