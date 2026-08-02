# E2E control-channel port

Status: in progress — Environment, Scenario Info, Map editor fields, and the
non-gesture setup in brush/state scenarios are now control-driven.

The control channel should replace X11 in every domain-editor scenario that is
setting editor state, running an editor feature, asserting emitted commands, or
positioning the camera for a capture. Domain-editor scenarios do not test their
own widget interaction. X11 remains the authority for the separate UI suite:
input routing, hit testing, hover, text editing, drag/stroke behaviour, and
dialog/widget layout.

Scenarios share a resettable Spring process with compatible launch environments
by default. Scenarios that change the project or require a fresh filesystem
opt into `@scenario(isolated=True)` and get their own process.

## Current API

Available now: typed editor `open`/`get`/`set`, typed registered-command
execution, camera `get`/`set`/`zoom`, ordered captures, and a reset boundary that
undoes native history before reloading native modules. This already removes
coordinates and waits from semantic editor tests.

Asset fields currently travel as schema text; a semantic, validated asset value
is not available yet. Editor action buttons, object create/select/place
operations, project/file-dialog operations, and synthetic in-engine input are
also not available. Those boundaries determine the partial and blocked rows
below.

## Proposed migration order

| Status | Scenarios | Plan |
| --- | --- | --- |
| Done | `lighting`, `sky`, `water`, `info-panel`, `map-editors` | Domain fields and emitted commands use control only. |
| Partial | `heightmap`, `texture-paint`, `metal-paint`, `grass-paint` | Scalar/editor setup uses control; the actual stroke, asset-grid choice, action selection, or project dialog remains X11. |
| UI / blocked | `teams-panel`, `settings-panel` | Teams needs typed add/select/edit handles before it can become a domain test. Settings owns the shading-dialog interaction contract. |
| Second batch | `props-panel`, `collision`, `units-panel`, `feature-placement-actions`, `brush-size`, `project-workflows`, `map-workflows` | Convert the domain state/command portion once object/project helpers exist. Move the remaining input setup out to focused UI coverage. |
| Camera-only cleanup | `pattern-preview`, `texture-paint`, `metal-paint`, `grass-paint`, `cursortip`, `deselect`, `rotation`, `selection-drag`, `object-actions`, `selection`, `clipboard-actions` | Done: deterministic framing uses `camera.zoom`; no domain scenario uses mouse-wheel camera zoom. A dedicated camera-wheel test is intentionally out of scope for now. |
| Keep X11 | `terrain-stationary-hold`, `heightmap`, all `chonsole-*`, `module-reload`, `developer-console`, `developer-console-copy`, `gallery`, `gallery-pickers`, `gallery-tooltips`, `gallery-dialogs`, `main-panel`, `hide-interface`, `all-editors`, `panel-tabs-are-choices`, `import-action`, `dialogs`, `project-status-bar`, `notifications`, `export-warning`, `ui-sweep`, `def-grid`, `feature-grid-tooltip-after-cursortip` | These explicitly test keyboard focus, pointer routing, held strokes, hover, clicking a control, modal layout, or rendering. Replacing their core interaction would stop testing what they exist to test. |

The former water UI scenario's terrain-basin stroke and `/water 4` input belong in focused
stroke/console tests, not in the water domain test. `map_export` and
`map_roundtrip` remain blocked until a project API is deliberately designed.

## Focused UI suite

The retained X11 scenarios should become a compact, cross-cutting UI suite:
one test per widget/interaction contract, not one copy per domain editor. The
existing gallery, picker, tooltip, dialog, Chonsole, input-state, toolbar, and
visual-sweep scenarios are its nucleus. When a domain scenario gives up a
click/drag/picker assertion, move that coverage here only if no existing UI
scenario already covers the same generic contract. `field_modal_handoff` is
the first such extraction: it covers modal-binding cleanup across editors
without being presented as Scenario Info coverage.

## API additions worth designing before the second batch

1. Typed asset fields: an `AssetPath`/asset-reference value accepted by
   `Editor.set`, validated against the live field schema.
2. Typed editor actions: invoke a named registered editor action through the
   same behaviour path as a button, with schema discovery and no raw strings.
3. Object domain handles: create, select, inspect, and mutate objects without
   pretending those operations are generic editor fields.
4. Project domain handles: create/save/load/export by typed request. Do not
   expose file-dialog clicks as an API.

Do not add `input.*` merely to avoid X11 in the retained scenarios. Its job is
to test the native input state machine and belongs only where pointer/keyboard
semantics are themselves under test.

## Progress

| Batch | Status | Notes |
| --- | --- | --- |
| Environment | done | `lighting`, `sky`, and `water` now cover their editor domain state. |
| Scenario Info | done | `info-panel` now sets and reads metadata through control. |
| Map editor fields | done | `map-editors` covers terrain, texture, metal, grass, and rendering fields through control. |
| Brush/state setup | partial | Scalar setup is control-driven; pointer gestures and picker/action contracts remain X11. |
| Focused UI suite | existing, to consolidate | Own generic editor/widget interaction coverage. |
| Team domain | blocked | Needs typed add/select/edit API; keep its current test explicitly UI until then. |
| API additions | proposed | Design only when the second batch is reached. |
| Second batch | blocked | Depends on typed object/project/action support. |
| Camera cleanup | done | Domain/object setup uses the typed camera surface; the only remaining wheel event is Chonsole suggestion-list scrolling. |
