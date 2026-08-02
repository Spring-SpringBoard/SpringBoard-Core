---
name: Programmatic control
description: A machine-facing channel that drives a running editor through its own editors, commands and state
---

# Programmatic control

A control channel lets a script drive a running SpringBoard the way a user
drives it — open an editor, set its fields, run a command, place the camera,
capture the result — without synthesising X11 input.

Status: **implemented for editor fields, domain dialogs, registered commands,
camera state, and ordered capture.**

## Why

Automation today clicks at hardcoded pixels and sleeps between steps. That is
slow (every step pays a conservative wait), silently wrong when a layout moves,
and it seizes the real pointer, so a run and a human cannot share a machine. A
control channel also does something the current approach cannot: attach to an
editor that is already running.

## Transport

Newline-delimited JSON-RPC 2.0 over loopback TCP, ephemeral port, discovered
through `control.json` in the session write dir and authenticated with a token
from that file.

TCP because it is the only bidirectional stream that behaves identically on
Linux, Windows and macOS from a stdlib Python client — CPython still exposes no
`AF_UNIX` on Windows. The ephemeral port keeps parallel sessions apart; the
write dir is already the unit of session isolation, so the client finds a
session by a directory it already knows.

`control.json` carries `port`, `token`, `instance_id`, `pid`, `protocol_version`
and `started_at`, is written atomically with owner-only permissions, and is
deleted on shutdown. A client must match `instance_id` after connecting, because
a crash leaves the file behind.

A listener thread parses requests and never touches engine state. Decoded
requests cross to the main thread on a queue drained once per `update()`;
replies return the same way. One request per line, no JSON-RPC batches —
requests on a connection apply in order and reply in order.

Project reloads replace the native module and therefore close existing sockets.
The Python client detects that replacement, waits for the new `instance_id`,
refreshes the schema, and reconnects subsequent calls; a caller does not need
to rebuild its editor or camera handles.

## First-class surfaces

**Editors** — `ui.open(tab, editor)`, `ui.set(editor, field, value)`,
`ui.get(editor, field)`. This is the user path: `Editor::set_field_value`
followed by `process_change` is exactly what a committed click runs, minus the
RmlUi event dispatch, and `take_state_request`/`drain_commands` carry the
consequences out unchanged. It is also the only surface that reaches settings
with no command behind them — shader parameters, view configuration, anything
whose effect is editor state. Setting up an editor for a human to look at lives
here too.

**Commands** — `command.execute(className, fields...)`. The registry in
`command_system/registry.rs` already maps `className` to a typed serde handler
and already runs through the undo history; the channel is a socket in front of
`SBC::route`. Cheaper than a field commit and reaches actions with no panel, but
it is a rung below the user path, so a test about a panel should not use it.

**State** — `describe()` returns tabs, editors, fields, types and current
values, built from the editor registry and field model that already exist. It
is what makes binding fail fast: a client resolves its handles at connect time,
so an unknown editor or field raises immediately with a list of what exists,
rather than silently doing nothing three minutes into a run.

Alongside these: `camera.set/get` (rendered position, direction, fov, and
controller distance/height), `camera.trace_screen_ray(x, y)`,
`camera.zoom(factor)`, `capture(path)`,
`runtime.barrier()` (two input-idle native updates, for ordering external input), and
`runtime.reload_native_modules()` for native-module lifecycle testing. The
reload deliberately preserves engine world/project state; it is not a project
reset.

**Dialogs** — `dialog.open/get/set/select/accept/cancel` controls typed
project/file dialogs through their existing action and modal paths. A domain
workflow can create a project, choose a VFS project, or save/export by name
without synthesising a click, text entry, or Enter key:

```python
project = sb.dialog("new_project").open()
project.set("name", "Example")
project.set("size_x", 32)
project.accept()

load = sb.dialog("load_project").open()
load.select("springboard/projects/Example.sdd")
load.accept()
```

## The Python client

`tools/control/`, a `control` package alongside `e2e`/`smoke`/`lint`, depending
on nothing outside the standard library — `socket` and `json` are the whole
transport. It splits the same way the plugin does: `handles.py` is the surface a
script works through, `transport.py` the socket and discovery under it.

`connect` fetches `describe` and every name is resolved by a lookup against it.
The live editor is the only authority on what exists — the set of editors
depends on build flags and on whatever registers itself later, so nothing about
it can be checked in.

A script therefore declares its handles at the top, and a typo costs a connect
rather than a run:

```python
with control.connect(write_dir) as sb:
    lighting = sb.editor("lightingEditor")           # raises here, listing the editors
    sun = sb.commands["SetSunParametersCommand"]     # and here, listing the commands

    lighting.groundDiffuseColor = (0.9, 0.45, 0.2, 1.0)  # and here, listing the fields
    lighting.shadowMode = "Full"

    sb.camera.set(position=(2048, 900, 2048), direction=(0, -1, 0), height=900)
    sun(dirX=0.5)
    sb.capture(out / "lit.png")
```

`sb.editor(name)` opens the editor and returns once the panel shows it, so the
declaration is also the setup.

A handle knows its own fields and their types, so an unknown field or a wrong
value type raises on assignment, before any call goes out. Field ids are the
schema's own, matching what `describe` and the command log show.

Anything the schema cannot express — a command the current project state
rejects — is a structured error from the call itself. Every call blocks until
its effect has landed, so a script reads as a straight sequence with no waits in
it. `RunState` grows a `.control` handle, letting a scenario move to the channel
a step at a time while the rest of it still clicks.

## Layout

`native/src/sbc/control/` separates the two halves so neither drifts into the
other:

- `api/` — the surface, one file per method group (`editors`, `dialogs`, `commands`,
  `camera`, `capture`, `schema`). Each goes through the seam its user action
  goes through, and knows nothing about sockets.
- `channel/` — the plumbing: `server` (socket and connections), `discovery`
  (`control.json`, token), `protocol` (JSON-RPC shapes and codes), `pending`
  (replies still waiting on an effect).
- `dispatch.rs` — the routing table and the per-tick pending sweep. The only
  file that knows both halves.

## When a call is done

A reply is sent once its effect has landed, not once the request was accepted:
`ui.open` answers when the editor is on screen, `dialog.open`/`dialog.accept`
answer when the modal opens/closes, `capture` when the image is on disk, and
`runtime.barrier` after two input-idle native updates. Requests on a
connection apply and answer in order, and `capture` is queued at
`draw_screen_post`, so an image already contains every call before it. No
scenario needs a sleep to make a screenshot honest.

Unknown method, unknown editor, unknown field, out-of-range value, and failed
deserialisation are all structured errors returned before anything is applied.
Nothing in this channel may fail by doing nothing.

## Scope

**Built**: `describe`, `ui.open/set/get`, `dialog.open/get/set/select/accept/cancel`, `command.execute`,
`camera.set/get/trace_screen_ray/zoom`,
`capture`, `runtime.barrier`, `runtime.reload_native_modules`. `SBC_CONTROL_FILE` names the discovery file and turns the channel on;
the E2E harness sets it per run and exposes the connection as
`run_state.control`.

**Later**: `input.press/move/release`, injecting screen-pixel coordinates into
SBC's own mouse callins. No X11 and no pointer takeover, but the real
`StateManager`, repeat timer and stroke undo-grouping still run — which is what
a brush stroke test needs and neither of the other surfaces provides. Also
`wait.until(predicate)`, evaluated in-engine, for something that is neither a
field nor a frame.

**Not this**: real OS input. Testing that a click at a pixel reaches the right
widget needs a real display server, and stays with the X11 harness.

## Relationship to the X11 harness

The two coexist. Feature scenarios — set things up, run the feature, look at the
result — move to the relevant domain module under `tools/e2e/scenarios/` and get
faster and layout-independent: `lighting` there covers the environment lighting domain, in
2s of scenario time against 14s. Scenarios genuinely about input routing, focus
and hit-testing keep clicking. See [e2e.md](e2e.md).
