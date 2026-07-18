---
name: Rust WIP refactor plan
description: Structural work to complete in rust-wip before selectively moving domains into rust-stable
---

# Rust WIP refactor plan

## Purpose

`rust-wip` is functionally broad but developed as a fast, exploratory workspace.
Before work is transferred into `rust-stable`, make its ownership boundaries and
module structure match [conventions.md](conventions.md). The stable branch should
then receive small, reviewable domain slices rather than architectural cleanup.

This is a plan, not a license to cherry-pick the existing WIP history. The
current 87 WIP-only commits are archaeological evidence; WIP is the source
snapshot and stable receives deliberate file-level transfers.

## Assessment baseline

On 2026-07-18, `rust-stable` was the merge base of `rust-wip`. The committed
delta was 463 files, +44,043 / -2,642 lines. The largest native additions were
the panel UI (+13,421 lines), Chonsole (+3,729), editing states (+2,999), and
developer console (+1,944).

The backend is already mostly feature-first: commands, models, and tests are
generally co-located under their feature directories. The main exception is the
native UI, which is organized by rendering technology under `panels/editors`.

## Refactors required before stable transfers

### 1. Make feature UI feature-owned

`panels/` must retain only reusable RmlUi infrastructure: host/document
lifecycle, fields, modal primitives, grid, input, and shared theme. Move actual
editor behaviour beside the feature it represents:

```text
objects/ui/{definitions,properties,collision}/
heightmap/ui/
grass/ui/
metal/ui/
textures/ui/
map_settings/ui/
teams/ui/
project/ui/
```

The generic panel registry can remain shared, but each feature must register its
own editor. This is the highest-value refactor: an Objects or Textures transfer
then becomes a coherent domain copy rather than surgery inside a generic folder.

### 2. Remove the state → panel dependency

Editing states currently depend on `panels::ModelShader` for ghost previews,
selection highlights, movement, and rotation. Extract world rendering to
`states` or a neutral renderer module. Map interaction must not depend on the
right-hand panel implementation.

### 3. Shrink the panel coordinator and editor contract

`PanelManager` currently owns document lifecycle, editor lifecycle, actions,
field commits/drags, modal coordination, state synchronisation, and cursor tips.
Keep a small composition point, but extract active-editor lifecycle, modal
coordination, toolbar actions, and field commits into focused components.

Likewise split the broad `Editor` trait into explicit capabilities around
lifecycle/rendering, field hosting, brush/state binding, and optional modal
ownership. Do not introduce a general event bus or UI framework: retain the
explicit update/input order, just give each concern a narrow owner.

### 4. Finish the Objects boundary

Refactor the Objects UI into definitions/catalog/filtering/placement/thumbnails,
properties, and collision submodules. Properties and collision must share
selection projection and object-field mapping rather than duplicate conversion
logic.

At the same time, complete TODO #1 in [todo.md](todo.md): replace generic
JSON-based Area/Feature/Unit object commands with concrete typed commands, and
cache static object-field descriptors. This makes Objects safer and smaller to
review in stable.

### 5. Split project persistence from the Project feature

Extract project paths plus save/load/export registrations into a neutral
project-IO/workspace module. Leave scenario metadata, archive export, reload,
map info, and project-editor functionality in `project/`. This is TODO #16 and
prevents each saving feature from depending on the whole Project feature.

### 6. Split the texture editor by ownership

Move material discovery/parsing into `textures`, separate saved-brush state, and
leave a thin UI composition layer. Texture/material ownership must not be
trapped in one large panel editor before the Textures domain is transferred.

### 7. Establish a shared native RmlUi theme

Centralize common text, color, border, opacity, button, toggle, dropdown, and
tooltip rules. Keep only document-specific layout in panel, Chonsole, and
developer-console stylesheets. This prevents future stable slices from changing
three visual systems for one control correction.

### 8. Separate E2E runner responsibilities

Split the `E2ERun` monolith into engine session lifecycle, input, assertions and
command-log reading, screenshots/artifacts, and reporting. Keep semantic UI
coordinates centralized in `scenarios/geometry.py`; that file already fixes the
previous scattered-coordinate problem.

## Do not rewrite these first

- Chonsole is already sensibly divided into catalog, completion, input, history,
  model, and views. Transfer it as one domain after shared RmlUi lifecycle work.
- Developer console has a useful actions/log/metrics/manager/view split. Limit
  restructuring to common lifecycle and theme extraction.
- Do not replace the command system wholesale; reconcile only its required WIP
  delta against stable.

## Completion criteria

Before the first stable transfer:

1. Feature UI no longer lives in `panels/editors`.
2. `states` no longer imports panel UI/rendering.
3. Project IO is independent of the Project feature.
4. The shared native theme has a single source of truth.
5. The E2E harness and verification ledger identify a feature's tests without
   relying on obsolete phase documents.
6. Duplicate model-factory registration fails loudly, as duplicate command
   registration already does.
