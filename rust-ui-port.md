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
| numeric (click-to-edit) | done — commits once, on Enter or blur; asserted |
| numeric (drag)          | done — polled cursor; engine reports no mouse_move |
| colour picker           | done — modal, SV+hue drag, OK/Cancel; asserted |
| checkbox / boolean      | done — `has_attribute`, one command; asserted |
| text / string           | done — Enter/blur commit once; asserted |
| choice / select         | renders; **behaviour untested** |
| asset picker            | done — VFS grid, navigate, select, OK; asserted |
| grid view               | done — reusable; clicks queued out of dispatch |
| material picker         | **not ported** (grid + material model) |
| unit / feature picker   | **not ported** (grid + RTT thumbnails) |
| dialogs                 | picker only |

### Views

| tab | view | status |
|---|---|---|
| Env | Lighting | done, asserted |
| Env | Sky | done — skybox picks from the VFS |
| Env | Water | done, asserted; three texture fields pick from bitmaps/ |
| Objects | Units / Features / Properties / Collision | not started |
| Map | all | not started |
| Misc | Info | done, asserted |
| Misc | Teams | not started |

The **developer console** (F8) is ported too, as `native/src/sbc/devconsole/`.
It is not an editor view: it owns its own RmlUi context and is enabled only when
`ui: rust`, exactly as the Chili and RmlUi consoles gate on their own UI. Log
lines arrive through the `add_console_line` callin, are classified by text
(`error`/`failed` → error, `warning` → warning) and rendered once per tick
rather than once per line. `Restart`, `Debug Mode` and `Toggle profiling` are
deliberately absent: the first needs `Spring.Reload`, the others drive Lua-side
state the native UI does not own.

## Known blockers

~~The panel cannot reach the project models.~~ Fixed: `Models::with` lifts the
panel out of the registry for its update, so `refresh_from_engine` takes
`&mut Models`. Views backed by project state (Info, Teams, object properties)
can now be ported.

~~Reference-image determinism is not yet proven.~~ Fixed. The differing pixels
were never the map: they were the engine's own `InfoConsole` overlay, which
prints a Lua state **pointer address** that changes every run. The native dev
console now sends `console 0` (correctly -- see the `send_commands` note below),
which hides that overlay. Two consecutive `native-panel` runs are now
pixel-identical across all 16 reference images, and `native-dev-console` across
all 5, so any diff is a real regression.

## TODO

- [ ] Material picker (Map's texture brushes): the grid is reusable; it needs a
      material model, not more UI.
- [ ] Objects → Units / Features: grid + 3D RTT thumbnails. Lua renders these
      with `<texture src="!N">` (a Lua dynamic texture); the native path needs an
      equivalent, and may need a new binding. Check before designing.
- [ ] Map → Settings / Terrain / Texture / Metal / Grass.
- [ ] Misc → Teams (project model; now unblocked).
- [ ] Objects → Properties, Collision (project model; now unblocked).
- [ ] Choice/select: renders, but no test asserts that changing it emits a
      command. `shadowMode` is an engine console action, so it emits none —
      assert the console action instead.
- [ ] Undo/redo: `on_history_events` marks the panel dirty, but only the open
      editor refreshes. Assert an undo of a lighting change restores the field.
- [ ] Toolbar action buttons (new/open/save/export); `#action-bar` is still an
      empty placeholder.
- [ ] Native chonsole: remove its dead `context_render` call.
- [ ] Dev console: no line-selection or Ctrl+C copy yet (the Lua one has both),
      and no `Restart` button.
- [ ] Visual parity gaps against Lua RmlUi, visible in the reference images:
      the `shadowMode` select is narrower and sits high; the toolbar action bar
      is an empty placeholder, so content starts ~30px higher.
- [ ] Field widths: Lua sizes numeric/colour buttons per-field (`width = 140`);
      the native fields hardcode 78/140.

## Live preview (`__preview`)

A drag should show its effect while it is happening, but must not bury the undo
stack under one command per frame. A command envelope carrying `"__preview":
true` is wrapped in `PreviewCommand`, whose `undoable()` is `false`: the command
manager executes it and never pushes it onto the history.

The colour picker uses this. Two things are easy to get wrong:

- Committing straight after previewing captures the *previewed* value as the
  "old" value, so undo would restore the previewed colour. The picker therefore
  re-applies the original (as a preview) before it commits.
- Cancelling must restore the original the same way, and emit no command at all.

`assert_previews()` in the e2e harness asserts the preview stream; the
`assert_command()` "exactly one" contract ignores previews entirely.

## Engine notes

- The engine renders every RmlUi context in `RmlGui::RenderFrame`, between
  `BeginFrame` and `PresentFrame`. A plugin must **not** call `context_render`.
- `messages().send_commands(command, rest)`: `rest` is a **second command**,
  joined to the first with a newline — it is *not* an argument. Arguments belong
  in the first string: `send_commands("console 0", "")`, never
  `send_commands("console", "0")` (which silently runs `console` and then `0`).
- A plugin document whose `body` spans the screen (needed to anchor an
  absolutely-positioned panel) will swallow every click on the map *and* in any
  other plugin context. Give such a body `pointer-events: none` and re-enable it
  (`pointer-events: auto`) on the widgets that should take input.
- The engine also feeds keyboard/text input straight to its RmlUi contexts, so a
  plugin never sees those keys through its own `key_press` call-in. Listen on
  the element and read `key_identifier` off `event_get_current()`.
- RmlUi fires `change` on a text input per keystroke. Commit on Enter or blur.
