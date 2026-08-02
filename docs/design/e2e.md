---
name: Graphical end-to-end testing
description: How the SBC E2E harness drives a real editor session and records reviewable evidence
---

# Graphical end-to-end testing

The E2E harness tests the editor as a user sees it. It launches Spring, finds
its window, drives mouse and keyboard input through X11, and records the
observable result. Grouped runs reuse one resettable process per compatible
launch environment by default; scenarios marked `@scenario(isolated=True)` get
their own process. It
complements the headless Smoke suite:
Smoke proves native integration and in-engine tests; E2E proves UI ownership,
input routing, and rendered behaviour.

Scenarios that are about a feature rather than about a widget belong in the
domain modules under `tools/e2e/scenarios/`, driven through the control channel
instead of X11 — no coordinates, no sleeps, and several times faster. See
[programmatic-control.md](programmatic-control.md).

## Run a scenario

```bash
just test-e2e map-workflows
just test-e2e map-workflows --tag ui
```

The runner writes the scenario report, input/event trace, command trace, engine
log, and individual screenshots under `artifacts/ui-e2e/`. A focused invocation
uses one run directory and writes `suite-report.md` beside it. A grouped
invocation puts its scenario directories and one aggregate `suite-report.md`
under a timestamped suite directory; every run report links back to that
summary. Review images at their native resolution.

## What a scenario may assert

Each scenario should use the narrowest observable assertion that proves its
claim.

- **Commands**: the command bridge recorded the expected committed command and
  fields. This proves an action was submitted, not that the engine necessarily
  rendered it correctly.
- **Engine log**: a lifecycle or asynchronous operation reached a named state,
  such as project reload or editor-state persistence. Wait for a new matching
  line instead of sleeping for a guessed duration.
- **Pixels**: a bounded screen region visibly changed, or a distinctive colour
  remains in a fixed region. Use this for rendered effects, previews, and
  round-trips; avoid comparing whole map frames because lighting and terrain
  shading are not pixel-stable across a reload.
- **Goldens**: a stable UI-only image matches a reviewed reference. Goldens are
  for control/layout regressions, not for dynamic map imagery.

A scenario should normally combine a command or log assertion with a visual
assertion when it changes visible editor state.

## Inputs and dependencies

The harness intentionally uses `xdotool` for real X11 mouse and keyboard
events. It exercises the same engine callback path as a desktop user, including
focus and modifier handling. Spring itself and an X11 display are therefore
required to run E2E tests.

The native plugin captures its own fully rendered framebuffer as PNG. Pillow
compares goldens and measures pixels. No desktop-capture or image-conversion
tool is required.

## Adding a scenario

1. Add a focused function in the relevant `tools/e2e/scenarios/` module and
   register it with `@scenario`.
2. Use shared geometry names rather than literal screen coordinates.
3. Capture only checkpoints needed for review; do not create diagnostic shots
   by default.
4. Prefer `wait_for_log` or `wait_for_command` to a fixed delay after an
   asynchronous action.
5. Run the target, inspect every produced screenshot, and record/review any
   new golden before committing it.

## Lifecycle

Each process owns a temporary Spring write directory. Shared cases with the
same launch environment reuse it after an undo/reload reset; isolated cases
get a fresh one. The directory is removed after logs and screenshots have been
copied to the artifact directory.
`--keep-open` preserves the process and write directory for diagnosis; it is
not normal test behaviour.
