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

## 1. Objects commands: make them concrete and fully typed

**What.** The three object commands are generic over `objType` and still carry
`serde_json::Value` (`AddObjectCommand.params`, `SetObjectParamCommand.key`/`value`).
Split them into concrete per-kind commands whose struct fields *are* the object's
fields — typed, deserialized straight from the wire, no `serde_json::Value`:

- Add:    `AddAreaCommand`, `AddFeatureCommand`, `AddUnitCommand`
- Remove: `RemoveAreaCommand`, `RemoveFeatureCommand`, `RemoveUnitCommand`
- Set:    `SetAreaParamCommand`, `SetFeatureParamCommand`, `SetUnitParamCommand`

Each `Add*`/`Set*` lists every field of its kind explicitly (`Set*` all
`Option<_>`; `Add*` requires the create params). Field names/types/ranges live in
`native/src/sbc/objects/model/<kind>_s11n/fields.rs` — keep in sync.

- **Area:** pos, size
- **Feature:** defName, pos, rot, vel, dir, mass, midAimPos, blocking,
  radiusHeight, collision, team, health, resources, rules
- **Unit:** defName, pos, rot, vel, dir, mass, midAimPos, maxRange, blocking,
  radiusHeight, collision, team, health, maxHealth, paralyze, capture, build,
  tooltip, stockpile, experience, neutral, fuel, movectrl, gravity,
  harvestStorage, resources, armored, crashing, rules, states, commands

**Why.** Compile-time field validation, no per-command JSON parse, undo state
already typed. Removes the last JSON from the objects command path, so the codec's
`json_to_object`/`parse_named_field` fall away.

**How.** One concrete command per kind via `register_command!`; serde derives do
the parsing. `ObjectManager`'s `ObjectKind` dispatch stays as-is.

---

## 2. Unit-struct commands are a registration gotcha

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

## 3. In-engine tests bypass the Lua command_manager (dispatch bugs invisible to CI)

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

## 4. Brush data structures: ditch nested HashMaps for vectors

[brush_filter_generator.rs](../../native/src/sbc/commands/heightmap/brush_filter_generator.rs)
ports SpringBoard's brush-filter cache verbatim as
`HashMap<String, HashMap<usize, HashMap<HashableFloat, HashMap<HashableFloat, HashMap<usize, f32>>>>>`.
That five-deep nesting (and the per-point `HashMap<usize, f32>` the brushes pass
around) is a mechanical port of the Lua; vectors / a flat keyed struct would be
far more efficient and readable. Refactor the whole brush system off nested
HashMaps once the behavior is locked in.

## 5. Load the brush greyscale directly in Rust

[set_heightmap_brush_command.rs](../../native/src/sbc/commands/set_heightmap_brush_command.rs)
receives the greyscale shape as a large array marshalled from Lua on every
`SetHeightmapBrushCommand`. Load the brush image directly in Rust so the big
array doesn't cross the bridge (ties into the async-IO image work in slice 2).

## 6. Object field descriptors allocate on every lookup

`ObjectHandler::descriptors()` currently returns `Vec<ObjectFieldDescriptor>` by
collecting each kind's `inventory` entries. This keeps field registration simple,
but `ObjectManager::descriptor()` and command parsing can allocate repeatedly for
what is effectively static metadata. Cache per-kind descriptor slices/maps once,
or generate static descriptor arrays alongside the field registry.

## 7. Feature s11n registers the same modelID twice (accepted warning)

**What.** The integration suite's only remaining red is a single Lua warning (not
an error, not a failed test — every test passes):

```
[s11n] Warning: [LuaUI] Trying to register featureS11N with existing modelID.
```

It fires during the feature add/remove tests. `_ObjectS11N:__Added`
([libs_sb/s11n/object_s11n.lua:73](../../libs_sb/s11n/object_s11n.lua)) warns and
bails when a modelID is already in `__m2s`, i.e. the gadget→widget mirror
(`S11NGadgetListener:OnCreateObject` → `WidgetAddObjectCommand`, in
[scen_edit/command/sync/object_sync.lua](../../scen_edit/command/sync/object_sync.lua))
re-registers a feature the widget side already holds.

**Why (suspected).** Same class as [#3](#3-in-engine-tests-bypass-the-lua-command_manager-dispatch-bugs-invisible-to-ci):
the objects Rust cutover and the still-Lua gadget/widget id mirroring can diverge
on who owns a modelID (see the "objects cutover: id authority diverges on redo"
finding). The direct-route tests don't exercise the Lua dispatch layer, so this
only shows up as an infolog warning, never a test failure.

**Status: accepted for now.** It is a benign duplicate-registration warning; the
mirror bails cleanly (`return` before double-inserting). Fixing it correctly means
tracing the gadget/widget feature-mirror + redo id-authority path, which belongs
with a proper objects-slice review, not a blind patch to the s11n registrar.
Revisit when reviewing the objects slice.

> Note: items #7 (run tests with `SYNCCHECK` on) and #8 (run tests with FP
> `Signal-NaNs` traps on) were written into the `SBC-rust-stable.sdd` worktree's
> copy of this file during the same session — consolidate the two worktrees'
> `todo.md` so all items live together (this entry may need renumbering).
