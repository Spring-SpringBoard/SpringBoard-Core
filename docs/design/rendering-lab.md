---
name: Rendering Lab
description: Panel that toggles, solos, inspects and documents the running renderer's features, addressed by concept id
---

# Rendering Lab

`Env → Rendering Lab`. The panel has no built-in controls. On open it requests the running
renderer's capabilities and builds its fields from the reply. Ship Game's renderer (Core WASM)
reports materials, lights, effects, frame passes and levels of detail. The generated-asset
shader gadget reports its material layers and light strengths.

Status: V1. Toggle, solo, reset, named debug views, one overlay (local lights), test scenes,
and a description for every control.

## Ids are concepts

Controls are named by rendering concept (`lighting.local`), not by implementation
(`shader.uniform.lightCount`). If the implementation changes, the id, panel and test scene
stay the same; only the renderer's description text changes.

## Terms

- **Control**: a feature switch or value, e.g. `material.dirt`, `lighting.ibl`, `frame.bloom`.
- **Debug view**: one shader quantity shown as color (albedo, normal, roughness, ...).
- **Test scene**: a fixed setup to inspect in, e.g. one ship with one light.
- **Solo**: switches off the controls listed in the feature's `solo` set, switches the feature
  on, and restores the previous values when the solo ends. The renderer defines each set.

## Protocol

Editor to renderer: a LuaRules message in SpringBoard's envelope (`lua_bridge::rules_message`,
tag `renderLab`), `data` is one command line:

```
list
set <id> <value>        value: 0/1 for a switch, a number otherwise
view <id>
overlay <id> <0|1>
solo <id> | solo off
reset
scene <id>
```

Renderer to editor: a JSON object prefixed `springboard|lab|`, sent with `SendLuaRulesMsg`.
The native module receives every rules message (`SBC::handle_lua_msg`). No Lua relay is used
because a game mounted as a mutator replaces SpringBoard's `LuaUI/main.lua`.

```json
{"kind":"capabilities","controls":[{"id":"lighting.local","name":"Local lights",
  "category":"lighting","kind":"switch","default":true,"value":true,
  "what":"...","how":"...","look":"...","solo":true}, ...],
 "categories":[{"id":"lighting","name":"Lighting"}, ...],
 "views":[{"id":"albedo","name":"Albedo"}, ...],
 "overlays":[{"id":"lights","name":"Local lights","what":"..."}],
 "scenes":[{"id":"local_light","name":"Dynamic light","what":"..."}],
 "values":{...},"view":"final","overlays_on":[],"solo":null,"scene":null,
 "lights":{"candidates":0,"chosen":0}}
{"kind":"values", ...same state fields...}
```

The renderer sends `values` after every command, so the panel shows the applied state.

## Code

| | |
| --- | --- |
| Panel | `native/src/sbc/render_lab/`: `renderer.rs` stores the last reply (a `Model` fed by the `renderLab` message handler), `model.rs` builds fields, `layout.rs` groups them by category, `behavior.rs` turns field changes into commands, `protocol.rs` sends them. |
| Push button | `panels/fields/button.rs`: value is the press count, so each press is a change. |
| Control channel | `describe` returns the open editor's live fields (`PanelManager::control_open_fields`). `Control.refresh_schema()` in `tools/control` fetches it again. `tools/sweep` drives the Lab's `debugView`. |
| Lua renderer | `LuaRules/Gadgets/api_sb_asset_shader.lua` implements the same protocol for the generated-asset shader. It disables itself when `luarules/wasm/shipgame-look.wasm` exists. |
| Ship Game | `wasm-src/crates/shipcore/src/lab/` (catalogue, wire format, state; engine-free, tested), `rules-synced/src/game_lab.rs` (relay, test scenes), `rules-unsynced/src/lab.rs` (applies values, overlay, camera). `just lab` opens the editor with the Lab; `just lab-sweep` captures every scene, view and solo. |

## Not done

A/B comparison with a wipe, shadow-map and LOD overlays, a light-candidate list, capture
metadata, per-pass GPU timings. Each fits the protocol as a new overlay or reply kind without
changing the panel's structure.
