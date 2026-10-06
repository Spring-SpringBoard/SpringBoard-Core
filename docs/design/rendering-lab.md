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

## Panels

The same capabilities feed more than one panel. A category or scene may list the panels it is
shown in (`"panels":["tuning"]`); one that lists none is shown in the Rendering Lab
(`render`). The `Effects` tab holds three more: `effectsStages` shows what names `stages`,
`effectsFire` what names `fire`, and `effectsTuning` what names `tuning` (Ship Game's effect
stages and weapons, one effect fired on demand, and the effect switches and scales). A category
naming several panels (the orbit camera) appears in each. Debug views and overlays are the
Rendering Lab's only. Every panel reads one renderer reply, so a change made in one shows in the
others.

The tab bar shows the Effects tab only once the running renderer's capabilities name one of its
panels; until a renderer answers, SpringBoard asks again now and then, less often once it has
stayed silent. Other games see no Effects tab. The control protocol's `describe` lists the tab
either way, with `"shown"`, and its editors open by name.

*Reset* sends `reset PANEL` once the renderer names panels at all, so each panel's Reset puts
back only its own controls; a renderer that names none is sent the plain `reset`.

A category marked `"hidden":true` is not laid out, but its controls are still fields a control
script can set and read: Ship Game's capture tool pauses on a frame this way.

### Updating in place

A panel's markup is built when the renderer's capabilities arrive or change, and when *Explain*
picks another control. A `values` reply does not rebuild it: the fields take the new values in
place, and the status line and the chosen scene's description are data bindings
(`render_lab_status`, `render_lab_scene_note`). Rebuilding on every reply replaced the whole panel
each time a readout changed, which flickered and broke a drag in progress. A field the user is
dragging or typing in (`Field::interacting`) keeps its own value until they let go; a reply
received meanwhile describes a value already passed.

`SBC_PANEL_STATS=1` logs, once a second, how many markup rebuilds and value refreshes the open
editor did.

## Control kinds

- `switch`: a toggle.
- `number`: a slider between `min` and `max`.
- `choice`: a dropdown of `choices`; the value sent and kept is the index.
- `button`: a push button. A press sends `set <id> 1`; the renderer keeps nothing, and state
  updates leave the button alone. Buttons next to each other in a category share a row evenly;
  a button alone is as wide as a switch, and a label stays on one line.

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
 "categories":[{"id":"lighting","name":"Lighting"}, {"id":"stage","name":"Stage","panels":["effects"]},
  {"id":"capture","name":"Capture","panels":["effects"],"hidden":true}, ...],
 "views":[{"id":"albedo","name":"Albedo"}, ...],
 "overlays":[{"id":"lights","name":"Local lights","what":"..."}],
 "scenes":[{"id":"local_light","name":"Dynamic light","what":"..."}],
 "values":{...},"view":"final","overlays_on":[],"solo":null,"scene":null,
 "lights":{"candidates":0,"chosen":0}}
{"kind":"values", ...same state fields...}
```

The renderer sends `values` after every command, so the panel shows the applied state.

The engine refuses a Lua message of 64 KiB or more (its packet size is 16 bits), and a
`capabilities` reply carrying every control's text is past that. A reply too long for one
message comes in parts, `springboard|lab-part|<reply>|<part>|<parts>|<text>` (`<part>` from 0),
whose texts join into the reply's JSON; `render_lab/parts.rs` joins them and the joined reply is
handled as one `springboard|lab|` message. A part of a new reply drops an unfinished one.

## Code

| | |
| --- | --- |
| Panel | `native/src/sbc/render_lab/`: `renderer.rs` stores the last reply (a `Model` fed by the `renderLab` message handler), `model.rs` builds one panel's fields, `layout.rs` groups them by category, `panel.rs` registers the two panels, `behavior.rs` turns field changes into commands, `protocol.rs` sends them, `parts.rs` joins a reply sent in parts. |
| Push button | `panels/fields/button.rs`: value is the press count, so each press is a change. |
| Control channel | `describe` returns the open editor's live fields (`PanelManager::control_open_fields`). `Control.refresh_schema()` in `tools/control` fetches it again. `tools/sweep` drives the Lab's `debugView`. |
| Ship Game | `wasm-src/crates/shipcore/src/lab/` (catalogue, wire format, state; engine-free, tested), `rules-synced/src/game_lab.rs` (relay, test scenes), `rules-unsynced/src/lab.rs` (applies values, overlay, camera). `just lab` opens the editor with the Lab; `just lab-sweep` captures every scene, view and solo. |

## Not done

A/B comparison with a wipe, shadow-map and LOD overlays, a light-candidate list, capture
metadata, per-pass GPU timings. Each fits the protocol as a new overlay or reply kind without
changing the panel's structure.
