---
name: Rendering Lab
description: A panel that switches, solos, inspects and explains whatever renderer is running, by concept rather than by uniform
---

# Rendering Lab

`Env → Rendering Lab`. The panel has no controls of its own: it asks the running renderer
what it offers and builds its fields from the answer. Ship Game's renderer (a Core WASM
module) answers with its materials, lights, effects, frame passes and levels of detail; the
generated-asset shader gadget answers with its material layers and light strengths. Another
game's renderer would answer with its own.

Status: **V1** — toggle, solo, reset, named debug views, one overlay (local lights), test
scenes, and the text beside every control.

## The rule

> Expose rendering concepts, not renderer implementation details.

A control is `lighting.local`, never `shader.uniform.lightCount`. When the implementation
under a concept changes (32 uniform lights today, clustered lights later) the id, the panel
and the test scene stay; only the renderer's explanation text changes.

## Three things kept apart

- **Control** — what is on: `material.dirt`, `lighting.ibl`, `frame.bloom` ...
- **Debug view** — what a pixel contains: albedo, normal, roughness ... one quantity as colour.
- **Test scene** — what to look at it in: one ship, one light, nothing else.

**Solo** is a preset over controls: whatever would drown a feature out goes off, the feature
comes on, and the values from before come back when the solo ends. Which controls a feature
drowns in is the renderer's to say (`solo` in its capabilities).

## Protocol

Editor → renderer, as a LuaRules message in SpringBoard's envelope
(`lua_bridge::rules_message`, tag `renderLab`, `data` a line of text):

```
list
set <id> <value>        value: 0/1 for a switch, a number otherwise
view <id>
overlay <id> <0|1>
solo <id> | solo off
reset
scene <id>
```

Renderer → editor, a JSON object prefixed `springboard|lab|`, sent as a **rules** message
(`SendLuaRulesMsg`). The native module hears every rules message (`SBC::handle_lua_msg`), so
this needs no Lua on the way — which matters, because a game mounted as a mutator replaces
SpringBoard's `LuaUI/main.lua` and no SpringBoard widget runs then.

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
{"kind":"values", ...the same tail...}
```

`values` is sent after every command, so the panel always shows what the renderer has,
not what it asked for.

## Where the pieces are

| | |
| --- | --- |
| Panel | `native/src/sbc/render_lab/` — `renderer.rs` keeps the last reply (a `Model`, fed by the `renderLab` message handler), `model.rs` builds fields from it, `layout.rs` lays them out by category, `behavior.rs` turns field changes into lines, `protocol.rs` sends them. |
| Push button | `panels/fields/button.rs` — its value is a press count, so every press is a change. |
| Control channel | `describe` lists the open editor's live fields (`PanelManager::control_open_fields`), since this panel has none until the renderer answers; `Control.refresh_schema()` in `tools/control` refetches. `tools/sweep` drives the Lab's `debugView`. |
| Lua renderer | `LuaRules/Gadgets/api_sb_asset_shader.lua` answers the same lines for the generated-asset shader, and stands down when the game's renderer (`luarules/wasm/shipgame-look.wasm`) is mounted. |
| Ship Game | `wasm-src/crates/shipcore/src/lab/` (catalogue, wire format, state; engine-free, tested), `rules-synced/src/game_lab.rs` (relay and test scenes), `rules-unsynced/src/lab.rs` (values into the renderer, overlay, camera). `just lab` there drives the panel through the control channel and captures every scene, view and solo. |

## Not yet

A/B states with a wipe, shadow-map and LOD overlays, the light-candidate inspector as a list,
capture metadata and GPU timings per pass. The protocol has room for all of them (more
overlays, more reply kinds); none needs the panel to change shape.
