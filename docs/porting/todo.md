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

## 8. Run SBC and its tests with engine sync checks ON

**What.** The engine is currently built with `SYNCCHECK=OFF` for SBC development
(binary reports `Sync-Check-Disabled`; recipe in the engine's
`SBC_PORT_MISSING_BINDINGS.md`). This was necessary because SBC's in-engine tests
abort under sync checks: `feature_add_remove`
([native/src/sbc/objects/tests/test_add_remove.rs](../../native/src/sbc/objects/tests/test_add_remove.rs))
constructs a synced object (`CreateFeature` → `CFeature`) from a context where
`CSyncChecker::InSyncedCode()` is false, tripping
`assert(InSyncedCode())` at `SyncedPrimitiveBase.h:47` (SIGABRT).

**Why it happens.** Synced-object construction is only legal inside synced code
(the counter Lua's synced callins raise). The engine fix `6408f57` wraps the
**Lua→native** path (`HandleLuaCall`) in `EnterSyncedCode`/`LeaveSyncedCode`, so
real SBC command dispatch via `Spring.InvokeNativeModule` is fine. But the
integration tests call `SBC::route(...)` **directly from the plugin's `update()`
tick** ([sbc.rs](../../native/src/sbc/sbc.rs) `run_if_requested`), which is an
*unsynced* callin — so the guard never runs and the assert fires. This is the same
"tests bypass the real dispatch path" gap as [#3](#3-in-engine-tests-bypass-the-lua-command_manager-dispatch-bugs-invisible-to-ci).

**Why fix it.** Turning sync checks off is fine for a map editor (SBC is not an
online deterministic client), but it removes a real safety net: a genuine desync
bug in a native synced mutator (bad ordering, unsynced input into synced state)
would now go undetected in CI. We want to be able to run the suite with the check
**on** so those bugs stay visible.

**How (not decided — needs the right seam, do NOT just fake `InSyncedCode()`):**
The honest fix is to make the tests exercise synced commands through the same
synced context real SBC uses, not to assert a synced flag while running unsynced.
Options to evaluate:
- Drive synced test commands from a genuinely-synced native callin (a `GameFrame`
  equivalent) instead of the unsynced `update()` tick — requires such a callin to
  exist/be wired for the plugin.
- Route synced tests through the Lua `command_manager` path (ties into [#3](#3-in-engine-tests-bypass-the-lua-command_manager-dispatch-bugs-invisible-to-ci)'s
  Lua-side test driver), so they inherit the `HandleLuaCall` synced scope.
- Add an engine seam that establishes synced context around native synced-ctrl
  mutators generally (engine-side design call).

Until then, SBC builds/tests run with `SYNCCHECK=OFF`.

## 9. Run SBC and its tests with FP signalling-NaN traps ON

**What.** Related to [#8](#8-run-sbc-and-its-tests-with-engine-sync-checks-on): the
debug engine also builds with signalling-NaN / FP-exception trapping (version
string `... Signal-NaNs`), which raises `SIGFPE` on `FE_INVALID`/`FE_DIVBYZERO`/
`FE_OVERFLOW` instead of producing inf/NaN. That trap is now **disabled** for the
SBC editor/testing build, because it aborts the plugin on benign floating-point
results.

**Why it happens.** `terrain_paint_diffuse` → `paint_shading_textures`
([native/src/sbc/textures/model/draw/shading.rs](../../native/src/sbc/textures/model/draw/shading.rs))
SIGFPEs in an optimized (`--release`) build. The map size is valid (5120×4096) and
the math is correct; the Rust optimizer auto-vectorizes the two
`region / map_size_{x,z}` divisions into a packed `divps` over
`[map_size_x, map_size_z, 0, 0]`, and the dead upper lanes compute `1.0/0.0 = inf`
— fatal only because the engine unmasks FP exceptions. A **debug** plugin build
(no vectorization) does not crash, confirming it's a codegen dead-lane artifact,
not a real div-by-zero.

**Why fix it.** Same trade as #8: keeping the trap off removes a real safety net
(a genuine NaN/inf from bad paint math would go undetected). We'd like to run with
it on.

**How (not decided — do NOT just hand-scalarize every divide):** source rewrites
(reciprocal-multiply, `f32::recip`) get re-vectorized into the same dead-lane
`divps`, and there are many vectorizable float-divides across the textures paint
code. The clean fix is engine-side: mask FP exceptions around the native plugin
`Update` callin (mirroring how `ENTER_SYNCED_CODE` scoping was proposed in #8), so
plugin SIMD dead-lane NaNs don't fault while engine sim code keeps the trap.
Details + the confirmed disassembly are in the engine's
`SBC_PORT_MISSING_BINDINGS.md` ("FP signalling-NaN traps disabled").

Until then, SBC builds/tests run with FP signalling-NaN traps off (no
`Signal-NaNs` in the engine version string).

## 10. Run texture/rendering IO on a background thread

**What.** Texture IO (save/load/export) currently runs synchronously on the
engine thread — the ops in `native/src/sbc/textures/ops/` do GPU work
(render-to-texture, readback, PNG encode/write) inline. Saving a project's
textures to disk can be heavy, and doing it on the main thread **freezes the
editor UI** while it runs.

**Why it matters.** Unlike grass/metal/heightmap IO — which reads the layer into
bytes on the engine thread then writes the file off-thread via the `jobs` /
`IoJob` seam — texture IO can't currently offload because it's tied to the
engine's GL context (GPU calls must run where the context is current). So the
expensive part (encode + file write) blocks the UI. A large map's diffuse export
in particular can stall the editor for a noticeable time.

**How (sketch).** Split the GPU part from the CPU part: do the minimal on-thread
GL work to get the pixels off the GPU (readback into a CPU buffer), then hand the
CPU-side encode + file write to a background worker (the same off-thread IO path
grass/metal/heightmap use). Needs a way to read a texture's pixels into a plain
buffer on the engine thread, after which the ops become "readback (on-thread) →
encode+write (off-thread)". Investigate whether a shared background
rendering/IO context is feasible for the readback itself.

## 11. Texture model uses `RefCell` — remove the runtime-panic surface

**What.** The texture model shares tile/shading surfaces as
`Rc<RefCell<TextureObj>>` ([surface.rs](../../native/src/sbc/textures/model/texture_model/surface.rs)),
so reads/writes go through `.borrow()` / `.borrow_mut()`. Those are **runtime**
borrow checks: a conflicting overlap panics at runtime instead of failing to
compile. The surfaces are `Rc`-shared between the tile store and the history/backup
system (two owners mutate the same surface), which is why interior mutability is
there.

**Why fix it.** We don't want any path where the editor can panic at runtime from a
double-borrow. Today the ops keep borrows tightly scoped (read fields into locals,
drop the guard before any call that might re-borrow), so there's no known live
overlap — but nothing at compile time *guarantees* it; a future change could
reintroduce one.

**How (not decided).** Rework the ownership so the surfaces don't need
`Rc<RefCell>` — e.g. a single owner (the store) hands out short-lived `&`/`&mut`,
with the history/backup side referring to surfaces by key `(i, j)` / name instead
of holding an `Rc` into them. Then the borrow checking is compile-time and the
panic surface is gone. Larger change to the model's sharing design; do it as its
own effort, not folded into an IO slice.

## 12. Bug: specular painting effect not visible

**What.** Painting specular does not produce the expected visual result in the
editor — the effect isn't showing up. Not yet root-caused; needs confirming
whether the specular shading texture is actually being written/applied, or whether
it's applied but not rendered (engine binding / material slot), or a UI/param
issue.

**Where to start.** The shading paint path
([native/src/sbc/textures/model/draw/shading.rs](../../native/src/sbc/textures/model/draw/shading.rs))
and how shading textures reach the engine's material (see the specular-race note
in the engine's `SBC_PORT_MISSING_BINDINGS.md`). Verify end-to-end: paint →
shading surface updated → pushed to the engine's specular slot → visible.

## 13. Bug: project load doesn't restore painted textures (brushes)

**What.** After save + load of a project, the map's painted textures are missing —
the loaded map has no brushes/paint. Save writes the tiles/shading to disk (the IO
ops run), but on load the painted result isn't showing on the map.

**Where to start.** The texture load path
([native/src/sbc/textures/ops/load.rs](../../native/src/sbc/textures/ops/load.rs)):
confirm the `texture-{i}-{j}.png` / `shading-{name}.png` files are found and read,
that `set_tile` actually blits them onto the engine map squares
(`set_map_square_texture`), and that load runs at the right time in project load
(the `ProjectLoadRegistration` fires, tiles are generated first, etc.). Likely
candidates: files not written where load looks, tile store not generated before
load, or the loaded textures not pushed to the live map.

## 14. Avoid extracting/copying the map compiler binary

**What.** [native/src/sbc/compile/ops/compiler.rs](../../native/src/sbc/compile/ops/compiler.rs)
`compiler_path` execs the bundled `mapcompile` in place when SBC runs from a
directory (`.sdd`), but falls back to reading the whole binary out of the VFS and
writing a temp copy (+ chmod) when it lives inside a zipped/rapid archive. That
extract-and-copy dance is wasteful; find a way to exec the compiler without
copying the binary (e.g. have the engine expose the archive's real path, or a
proper VFS extract-to-cache), and drop `extract_executable`.

## 15. Untangle the `project` slice: utility vs. feature

**What.** `native/src/sbc/project/` currently mixes two things: (a) an
**SBC-wide utility** used by every feature slice — `ProjectPaths`
([paths.rs](../../native/src/sbc/project/paths.rs)) plus the save / load / export
registries ([io_registries/](../../native/src/sbc/project/io_registries/)) that
grass/metal/heightmap/textures all register into — and (b) the **project feature
itself** (project info, spring-archive export, reload, s11n, map-info, the
editor model IO). Those are different concerns living in one slice.

**Where to start.** Consider splitting the cross-cutting utility (paths +
io_registries, the "how a project is saved/loaded/exported" plumbing) out from
the project *feature* commands/jobs/ops, so feature slices depend only on the
utility and not on the whole project slice. While there, move some files out of
`project/ops/` to a better home and tighten naming — several `ops/` modules
(`lua_writer`, `model_codec`, `map_info`, `project_info`, `spring_archive`,
`archive`/`archive_assets`) are a grab-bag; group/rename them so each reads as
what it does.

## 16. Simplify/decouple command part from SBC & reconsider event simplification

SBC encapsulating all objects, doing event dispatch and now also doing fairly intricate command stuff.
The command part is particularly low level and doesn't belong here imo.

I wonder if events could also be simplified or just done better, so we don't have to register ALL events & dispatch them manually.
Some sort of codegen could help.

## 17. Dev console log render: don't rebuild all rows every dirty frame

`LogPanel::render()` rebuilds the entire `Vec<RmlLogRow>` from all lines whenever
`dirty` is true. The common case is "one new line arrived" — cloning and clamping
thousands of strings to append one row is wasteful. Needs benchmarking first to
confirm it's actually a problem at real line counts, then consider incremental
append (track `rendered_count`, only push the delta).

## 18. Consider removing models.get() from various event listeners

Particularly nasty to see ConsoleController implement a Model.. even though there's a ConsoleModel which does not.

## 19. Proper enum return for trace_screen_ray

The hit_type here is current an int, making it difficult to use:
```rs
let (hit_type, _hit_id, coords) = interface.camera().trace_screen_ray(x, y, options.into())?;
```

# 20. Purge/consolidate unit testing

Some files have unit testing inside them, at the end. Personally think it hurts readability and makes the file larger than it needs be.
Also not sure unit tests really catch anything useful, it's usually very simple things that are tested.
IMO: Either move it to separate files, ideally in separate dirs or remove it.


# 21. Step-down for private structs

Private structs should be below private ones. Needs a lint-rule and application project wide

# 22. Unify UI creatin for the future framework cleanup

See 23. This is our goal in terms of developer experience.
However, before we get that, we should unify all rmlui, to ensure it follows the same pattern, and that there is indeed a pattern to begin with.
After unifying rmlui, we can then create a framework and apply it almost mechanically.

# 23. Some macro/magic for binding UI

Currently a lot of work, mostly boilerplate, goes into binding to rmlui.

You have to do the following:
- Create context
- Bind fields
- Create document
- Attach listeners

This should _probably_ be doable declaratively, there's very little unique stuff to do here, it's almost always mechanical.
Even if you don't automagically scan .rml/rcss and various Rust files, you could declare things by specifying .ui, .rcss, and saying which variables you want it to bind to, and the framework should do the rest.

likewise for setting up those listeners & draining the queue. It's quite convoluted at the per-UI level, lots of Rc+RefCell convoluted code to consume clicks

# 24. 0 radius & reclaim time, right or wrong?

    // A def may carry zero radius/height/reclaimTime, which the engine refuses
    // and clamps, so only the state after one replay is a fixed point.
    let before = replay_objects(ctx, &model_ids)?;
    let replayed = replay_objects(ctx, &model_ids)?;
    assert_objects_eq("full feature object replay", &before, &replayed)?;

see test_set_params.rs and relevant engine clamping.
The concern (https://github.com/beyond-all-reason/RecoilEngine/pull/3193#pullrequestreview-4905525942) was that it might crash reclaim time, or cause some draw issues,
but I'm not again considering the possibility that this might have been right, if certain features are actually serialized like this to begin with: are geovents 0 radius & 0 reclaimtime by default?

# 25. devconsole cleanup hacky noise suppression in session.rs

session.rs has this:
```rs
// TODO: Cleanup this hack. Probably added to suppress some kind of noise.
fn show_console_line(message: &str) -> bool {
    !message.contains("[CAS::GASCB] Archive file=")
}
```

probably added at one point to suppress spammy code, but ideally we shouldn't be doing thi

# 26. text selection & manipulation belongs to rmlui and not specific UI

devconsole does this:

```rs
  pub fn key_press(&mut self, key_code: i32, mods: KeyMods) -> Result<bool, Error> {
      self.note_key_press(key_code);
      if !self.enabled || !self.view.is_ready() {
          return Ok(false);
      }
      if is_key(&self.interface, key_code, "f8") {
          let visible = !self.view.visible();
          self.view.set_visible(&self.interface, visible)?;
          self.refresh_toggles()?;
          return Ok(true);
      }
      if !self.view.visible() {
          return Ok(false);
      }
      let ctrl = self.ctrl_held(mods);
      if ctrl && is_key(&self.interface, key_code, "a") {
          self.view.select_all(self.model.rendered_count());
          self.model.mark_dirty();
          return Ok(true);
      }
      if ctrl && is_key(&self.interface, key_code, "c") {
          self.copy_selection();
          return Ok(true);
      }
      Ok(false)
  }
  ```

  realistically, most of it is stuff (at least bottom with selection and copy) that rmlui/engine should be doing, and not per UI components

# 27. update rust & pthon packages (pyproject is outdated)

do this once we've fully migrated everything from rust-wip here

# 28. (optional) Always-on control server — remove the `SBC_CONTROL_FILE` gate

The control server (`native/src/sbc/control/`) is currently gated behind the `SBC_CONTROL_FILE` env var and wrapped in `Option<ControlServer>`. It only starts when the e2e harness sets that var. But the control server is meant for both e2e testing and programmatic control (Blender-style Python API equivalent), so it should always be running.

**What needs to happen:**
- Add an engine binding to expose the write dir to native modules (there is no Rust-side `get_write_dir()` — the Lua side gets it from the launcher via the `_sl_write_path` mod option, but the launcher is going away). The engine knows its write dir internally (`dataDirLocater.GetWriteDirPath()` in C++, set via `--write-dir`), it's just not wired into the native plugin API.
- Default the discovery file to `<write_dir>/control.json` so the server can start without external configuration.
- `SBC_CONTROL_FILE` becomes an optional override for the discovery path, not a gate.
- Remove the `Option` wrapper — `ControlServer` is always present.

# 29. Failable callouts

I see a ton of callouts that return result. Is this all senseless?
My guess is they can only really return Errors for the first moment that they're not initialized.
This is done at plugin boot so it's a great disservice to 99% of the code to have to test this everywhere.

```rs
    let direction = camera
        .get_camera_direction()
        .map_err(|err| ControlError::failed(format!("get_camera_direction: {err:?}")))?;
```