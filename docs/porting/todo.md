---
name: TODO — deferred improvements
description: Things worth doing that were raised mid-slice but deliberately not done in stable; pick up in wip
---

# TODO

Improvements raised while working a slice but intentionally deferred (out of scope
for the slice being reviewed, or needing infra that doesn't exist yet). Each entry
says what, why, and a sketch of how. Pick these up in **wip**, not by patching
stable mid-review.

---

## 1. Unit-struct commands are a registration gotcha

**What.** A control command with no payload is written as a braced struct with an
empty body specifically so it deserializes:

```rust
// Braced (not unit) struct so it deserializes from the `{className: ...}`
// payload — serde can't build a unit struct from a JSON map.
#[derive(Deserialize)]
pub struct UndoCommand {}
```

If you write the natural `pub struct UndoCommand;` (unit struct) instead, it
compiles and registers fine but **fails at runtime** with
`invalid type: map, expected unit struct UndoCommand`. This bit us: `UndoCommand`
/ `RedoCommand` / `ClearUndoRedoCommand` were unit structs and had never worked
end-to-end until found by manual testing.

**Why it happens.** `register_command!`
([native/src/sbc/commands/command_system/registry.rs](../../native/src/sbc/commands/command_system/registry.rs))
deserializes the **whole** payload into the command type:

```rust
let cmd: $ty = from_value($class_name, value)?;  // value is a JSON object/map
```

A JSON object can't deserialize into a unit struct (serde wants null/unit). A
braced empty struct works because it accepts a map and ignores the extra
`className` field. So the data shape (always a map with `className`) and unit
structs are fundamentally incompatible under the current handler.

**Why this is worth fixing.** It's a silent footgun: the idiomatic Rust spelling
for a no-data command (`struct Foo;`) compiles, registers, and then fails only at
runtime, only when that command is actually dispatched. Every future no-payload
command (clear-redo, more control commands, widget-notify acks, …) hits it.

**Fix options (rough order of effort):**

1. **Cheapest — make `register_command!` robust.** Strip the `className` key and,
   if what remains is empty, deserialize from `serde_json::Value::Null` instead of
   the map. Then a unit struct `Foo;` deserializes fine. One change in the macro;
   no per-command change. Downside: a little magic in the handler.

2. **Better — a `derive(Command)` proc-macro** (what the user asked for). A new
   in-house proc-macro crate under `native/` (there's none today; `ctrl_macros`
   is external). `#[derive(Command)]` would:
   - generate the `inventory::submit!` registration (replacing the manual
     `register_command!(Ty, "Name")` line), keyed off the type name or a
     `#[command(name = "...")]` attribute;
   - generate a deserialize path that works for **both** unit structs and structs
     with fields (e.g. emit a `From<()>`/`Default`-based construction for
     fieldless types, field deserialization otherwise);
   - keep the "one self-contained file per command, no central edit" property
     that [conventions.md](conventions.md#code-structure) requires.

   This removes the gotcha *and* collapses the two-line (`derive(Deserialize)` +
   `register_command!`) boilerplate into one derive. Unit structs "just work".

**Recommendation.** Do option 2 — it's the durable fix and matches the existing
auto-registration design philosophy. Until then, the braced-struct workaround is
in place and commented at each site
([undo_command.rs](../../native/src/sbc/commands/command_system/undo_command.rs),
[redo_command.rs](../../native/src/sbc/commands/command_system/redo_command.rs),
[clear_undo_redo_command.rs](../../native/src/sbc/commands/command_system/clear_undo_redo_command.rs)).

---

## 2. In-engine tests bypass the Lua command_manager (dispatch bugs invisible to CI)

**What.** The in-engine integration tests
([native/src/sbc/tests/](../../native/src/sbc/tests/)) drive Rust **directly**
via `SBC::route(...)`. They never go through Lua's `command_manager`, so they
verify Rust-side command logic (execute, undo/redo, streaming) but **cannot catch
bugs in the Lua dispatch layer**: per-command flips, cross-state forwarding, or a
command reaching the single native manager the wrong number of times.

**Why it matters.** Concrete miss (found only by manual in-game testing): a synced
command that cross-executes into the widget (`SetMultipleCommandModeCommand`,
whose Lua `:execute()` re-runs itself in the widget) hit the one native
`CommandManager` **twice** per toggle, desyncing its streaming state
(`streaming_commands: already streaming / not streaming` spam, one pair per brush
stroke). The Rust `terrain_drag_stroke` test exercises the streaming *lifecycle*
but, bypassing Lua, stayed green throughout. Fixed in
[command_manager.lua](../../scen_edit/command/command_manager.lua) (native
dispatch gated to the gadget).

**Fix.** Build the Lua-side test driver already flagged as a precondition in
[conventions.md → "Verifying the bridge end-to-end"](conventions.md). It should
drive a real drag stroke through `command_manager:execute()` with both Lua states
live (gadget + widget), then assert:
- the infolog has **zero** `streaming_commands` errors, and
- the stroke is a single undo unit (one undo reverts the whole drag).

That closes the gap — without it, Lua dispatch regressions are invisible to CI
and only caught by hand.

---

## 3. Brush data structures: ditch nested HashMaps for vectors

[brush_filter_generator.rs](../../native/src/sbc/commands/heightmap/brush_filter_generator.rs)
ports SpringBoard's brush-filter cache verbatim as
`HashMap<String, HashMap<usize, HashMap<HashableFloat, HashMap<HashableFloat, HashMap<usize, f32>>>>>`.
That five-deep nesting (and the per-point `HashMap<usize, f32>` the brushes pass
around) is a mechanical port of the Lua; vectors / a flat keyed struct would be
far more efficient and readable. Refactor the whole brush system off nested
HashMaps once the behavior is locked in.

## 4. Load the brush greyscale directly in Rust

[set_heightmap_brush_command.rs](../../native/src/sbc/commands/set_heightmap_brush_command.rs)
receives the greyscale shape as a large array marshalled from Lua on every
`SetHeightmapBrushCommand`. Load the brush image directly in Rust so the big
array doesn't cross the bridge (ties into the async-IO image work in slice 2).
