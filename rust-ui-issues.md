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
| Map | Terrain | ported — brush fields only, painting not wired |
| Map | Texture | ported — brush fields only; no material picker |
| Map | Metal | ported — brush fields only, painting not wired |
| Map | Grass | ported — `grassDetail` applies; painting not wired |
| Env | Lighting / Sky / Water | ported |
| Misc | Info | ported |
| Misc | Teams | ported |
| — | Toolbar action buttons | `#action-bar` is an empty placeholder |

Caveats on the views marked ported:

- **Brush editors configure a brush nothing applies.** Painting is still driven
  by the Lua editing states, which do not run under `ui: rust`. The panels are
  there; the map click that consumes them is not.
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

- `messages().send_commands(command, rest)`: `rest` is a **second command**,
  newline-joined — not an argument. `send_commands("console 0", "")`.
- Some engine commands (`luaui reload`) run synchronously and destroy RmlUi
  underneath the caller. Never touch the DOM after dispatching one.
- A plugin document whose `body` spans the screen swallows clicks meant for the
  map and for other plugin contexts. Give it `pointer-events: none`.
- The engine renders every RmlUi context itself; a plugin must not call
  `context_render`.
