# Native UI — known issues

Reported by the user, 2026-07-10. Ordered by kind, not priority. Fix these
*iteratively, after the breadth-first port lands* — the port is the priority,
not polish on the four views that exist.

Working agreement for this port:

- **Breadth before depth.** Port every view first, then fix.
- **Do not** re-run the pixel-exact golden suite as a matter of course. It is
  slow and it only covers a sliver of the editor. Reach for it when a visual
  change needs pinning down.
- **ASAN must stay on** (`USE_ASAN=ON`). RmlUi's bindings — Lua *and* native —
  are fragile; without ASAN a use-after-free reads as a bare SIGSEGV and costs
  hours. Check `nm -D <spring> | grep -c __asan` if in doubt: `0` means it is
  off and any "no errors" result is meaningless.
- The wanted safety net is a **fast, broad smoke test** that opens every tab and
  every editor and clicks the controls, asserting nothing broke. Not a
  screenshot comparison. Breakage = crash, ASAN report, Lua/RmlUi error, or a
  command that fails to dispatch.

## Fixed

- [x] **`luaui reload` segfaults.** `RmlGui::Shutdown()` destroys every RmlUi
      context; all three views cached dangling handles. Also,
      `send_commands("luaui reload")` tears RmlUi down synchronously inside the
      click handler, so the rest of that handler ran against freed memory.
      Fixed in `f9124ff1`.
- [x] **ASAN was disabled.** `USE_ASAN:BOOL=OFF` in the engine build, no
      `libasan` linked. Re-enabled.

## Correctness

- [x] **Numeric drag only applied on release.** Now previews per drag step via
      `__preview` and commits one undoable command on release, restoring the
      pre-drag value first so undo returns to it.
- [ ] **`Misc → Info` fields start empty.** Lua pre-fills name and author
      (from the project defaults / player name). The native view reads
      `ScenarioInfoManager` and shows whatever is there — which is nothing.
      Find where Lua seeds these and do the same.
- [ ] **Cheating / GodMode toggles lag by one action, and GodMode reads
      inverted.** `refresh_toggles` runs immediately after `send_commands`, but
      the engine applies the command later, so the button shows the *previous*
      state. Read the state on the next tick, not straight after dispatch, and
      re-check `is_god_mode_enabled`'s polarity.
- [ ] **Problems filter loses scroll position.** Toggling it re-renders the log
      from scratch and the container jumps. Preserve the scroll offset (or pin
      to bottom when already at the bottom).

## Dev console fidelity

- [ ] **Buttons and toggles look wrong** — too small, wrong styling. Compare
      against the Chili and RmlUi consoles (`LuaUI/rmlui/dbg_dev_console.css`)
      and match them, rather than inventing a look.
- [ ] **No text selection at all**, so no multi-line select and no Ctrl+C copy.
      The Lua RmlUi console does both. This is the single most-used feature of
      the console after reading it.
- [ ] No `Restart` button (needs `Spring.Reload`; no native binding yet).
- [ ] No `Debug Mode` / `Toggle profiling` (Lua-side state).

## Port status

| Tab | View | State |
|-----|------|-------|
| Objects | Units | ported — grid + search; **no thumbnails** |
| Objects | Features | ported — grid + search; **no thumbnails** |
| Objects | Properties | not started (needs the selection model) |
| Objects | Collision | not started (needs the selection model) |
| Map | Settings | ported |
| Map | Terrain | ported — Add / Set / Smooth all paint |
| Map | Texture | ported — Paint only; no material picker (diffuse channel) |
| Map | Metal | ported — paints |
| Map | Grass | ported — paints; `grassDetail` writes the engine config |
| Env | Lighting / Sky / Water | ported |
| Misc | Info | ported |
| Misc | Teams | ported |
| — | Toolbar action buttons | `#action-bar` is an empty placeholder |

## Editing states (`native/src/sbc/states/`)

The state machine is ported: a click on the map now does something. States queue
command envelopes and the plugin routes them, so a brush stroke gets undo for
free — press opens a `SetMultipleCommandMode` group, release closes it.

| Lua state | Ported |
|-----------|--------|
| `state_manager`, `abstract_state` | yes (`manager.rs`, `state.rs`) |
| `default_state` | as a no-op: the engine keeps camera + selection |
| `abstract_map_editing_state` + `abstract_heightmap_editing_state` | yes (`map_editing.rs`) |
| `terrain_shape_modify` / `terrain_smooth` / `terrain_set` | yes |
| `metal_editing_state`, `grass_editing_state` | yes |
| `terrain_change_texture_state` | partly: `paint` mode, diffuse channel only |
| `add_object_state` | partly: one object per click, no scatter, no ghost |
| `select_object_state`, `drag_object_state`, `rotate_object_state` | **no** |
| `rectangle_select_state`, `add_rect_state`, `resize_area_state` | **no** |
| `brush_object_state`, `terrain_change_dnts_state` | **no** |

Notes on what is there:

- Brush **shapes are decoded natively** from the pattern image (`shapes.rs`)
  rather than rendered into an FBO and read back, as `TerrainManager:generateShape`
  does. It works before the first frame and needs no GL.
- **Mouse wheel**: Shift resizes the brush, Alt rotates it, and the panel's
  fields follow (shared `BrushSettings` model, reconciled each tick).
- **No brush outline is drawn under the cursor.** Lua's `DrawWorld` renders the
  pattern on the ground with a shader. There is no native world-draw binding.

Caveats on the views marked ported:

- **Objects → Properties / Collision** need the selection model, which does not
  exist natively; the states that would drive it are the unported ones above.
- **Unit/Feature grids have no thumbnails.** Lua renders each definition to a
  Lua dynamic texture and shows it with `<texture src="!N">`. There is no native
  render-to-texture binding. Build pictures are deliberately not used instead —
  many games have none. This needs an engine binding.
- **Objects → Properties / Collision** both operate on the current selection,
  which the native panel does not track yet.
- The **material picker** (Texture's `mapMaterials`) is missing: the grid is
  reusable, it needs a material model, not more UI.
- Undo/redo only refreshes the *open* editor.
- Nothing asserts the choice/select control dispatches anything.

## Engine notes worth remembering

- `Camera.TraceScreenRay`'s `onlyCoords` was accepted and **ignored**, so a unit
  under the cursor shadowed the ground and a brush would paint on its hull.
  Fixed: it maps onto `GuiTraceRay`'s `groundOnly`, and `ignoreWater` is now
  passed through too. `hitType` is `3` for ground (`0` miss, `1` unit, `2`
  feature) — not `0`.
- `messages().send_commands(command, rest)`: `rest` is a **second command**,
  newline-joined — not an argument. `send_commands("console 0", "")`.
- Editor assets (`brush_patterns/`, `brush_textures/`, `detail/`) live under
  `springboard/assets/core/`. Lua resolves an editor's `rootDir` against the
  folders `AssetsManager` registers; there is only one, so native spells the
  full VFS path out.
- Some engine commands (`luaui reload`) run synchronously and destroy RmlUi
  underneath the caller. Never touch the DOM after dispatching one.
- A plugin document whose `body` spans the screen swallows clicks meant for the
  map and for other plugin contexts. Give it `pointer-events: none`.
- The engine renders every RmlUi context itself; a plugin must not call
  `context_render`.
