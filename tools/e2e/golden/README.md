# Golden images

Reference screenshots, compared against every run. A golden only means something
if a human knows what it is *supposed* to show, so each one is listed below with
the thing it pins down. If a golden changes, this file says whether that change
is a bug or an improvement.

Provenance: an image captured by the agent is `ai-reviewed` (see `review.json`
beside it). It becomes `approved` only when a human says so:

    just goldens-status             # what exists, and what still awaits approval
    just goldens-approve <case>     # the human OK; the agent never runs this

## What a golden can and cannot catch

The **panel renders bit-stably** — two runs produce identical pixels — so panel
crops are compared near-exactly (`PANEL_TOLERANCE`, 20px, absorbs an antialiased
edge). Any real UI change is hundreds of pixels.

The **map does not**. The engine's tree render shimmers between runs: a fringe
around each tree's silhouette, ~700px per tree, and a frame can hold four trees
(two objects plus their two ghosts). Map goldens therefore run at a deliberately
coarse `MAP_TOLERANCE` (4000px) and are a **gross** regression check — they catch
a ghost that stopped drawing or an object that never got placed, and they cannot
see a few-hundred-pixel change.

The fine detail on the map is asserted *without* pixels, which is exact and noise
free:
- `count_color` — the selection box is pure `#00FF00` and nothing else on the map
  is, so counting those pixels says exactly whether it is drawn;
- the command log — what the UI actually sent to the bridge.

Two things are forced still so captures repeat at all (see `runner.py`):
`SBC_STILL_MODELS` freezes the spinning def thumbnails, and `SBC_HIDE_CONSOLE`
starts the dev console hidden — its log text is uncontrollable (timestamps, ids)
and would break every frame it appeared in.

---

## def-grid-rust

The fastest look at thumbnail rendering: open Objects → Features, capture, stop.

| screen | what it pins down |
| --- | --- |
| `def-grid` | The def grid: every tree model rendered upright, full crown, filling its cell, on the tinted background. Catches the whole thumbnail pipeline — RTT, the model shader, the framing, and the alphabetical, stable ordering. |

## units-panel-rust

Units and Features: the grid, its filters, and placement.

| screen | what it pins down |
| --- | --- |
| `units-open` | The Units view and *its* filters (Type + Terrain, no Wreck). |
| `features-open` | The Features view: Type/Wreck/Terrain filters, search, grid. |
| `features-brush-fields` | Brush mode swaps the placement fields — `amount` goes, size/spread/noise and the rotation ranges appear. |
| `before-place` / `feature-placed` | The tree really lands on the map. The pair is diffed, so the command reaching the bridge is not taken as proof. |
| `amount-5-preview` | Amount 5 ghosts **five** trees, at the exact spots the click will use — the preview and the placement must not disagree. Captured with the cursor in place (`park=False`), since the ghosts follow it. |
| `before-amount-5` / `amount-5-placed` | Five more trees actually appear. |
| `features-wreckage-empty` | Type = Wreckage empties the grid: the filter filters, rather than merely rendering. |

## props-panel-rust

Properties: editing the selected object.

| screen | what it pins down |
| --- | --- |
| `feature-selected` | A placed feature can be selected (Add mode left first, or every click would keep placing). |
| `props-open` | The whole Properties form: Pos/Rot/Dir/Vel, Health, Mass, Blocking, Radius, Collision, Team, Resources. |
| `before-move` / `props-pos-edited` | Typing into Pos X changes the field *and* sends the whole vector. |
| `props-pos-dragging` | Mid-drag on a numeric field: the pointer is pinned to where the drag began and drawn as the empty cursor — nothing follows the mouse across the panel. `park=False`, or moving the pointer would fight the drag's own warp. |
| `props-pos-dragged` | The drag committed a value. |
| `props-drag-released-outside` | A drag released far outside the panel still ends. This is the one RmlUi drag-capture actually delivers; the engine never hands the plugin a release for a press RmlUi consumed. |
| `props-blocking-toggled` | A checkbox commits. |
| `props-after-map-clicks` | Clicking the map afterwards does not re-enter placement. |

## collision-rust

The collision volume, which is the point of the editor — so it is shown, not just commanded.

| screen | what it pins down |
| --- | --- |
| `volume-hidden` | Before "Show volume": no volume drawn. |
| `volume-shown` | The debug volume appears over the object. |
| `volume-scaled` | Scaling an axis **redraws it bigger**. A command reaching the bridge would not show that. |
| `volume-type-changed` | A different volume type is a different shape on screen. |
| `collision-fields` | The Collision form itself. |

## selection-rust

Rectangle select.

| screen | what it pins down |
| --- | --- |
| `box-dragging` | The selection rectangle is drawn while dragging. `park=False` — the box is drawn *to* the cursor, so the cursor position is the subject. |
| `box-selected` | The feature ends up selected (green box). |
| `props-after-box-select` | Proof it is really selected: Properties can edit it. Nothing to edit means nothing was selected. |

## deselect-rust

Deselecting has to clear the box, not just the selection — a box left behind is an
object the editor thinks it still has.

| screen | what it pins down |
| --- | --- |
| `feature-unselected` | Baseline: no box. |
| `feature-selected` | Clicking the feature draws the box. |
| `feature-escaped` | Escape clears it. |
| `feature-deselected` | Clicking empty ground clears it. |
| `box-selected` | A box-select selects. |
| `box-selected-empty` | A box-select over empty ground **drops** the previous selection. |

## rotation-rust

Ctrl-drag rotates the selection about its midpoint.

| screen | what it pins down |
| --- | --- |
| `before-rotate` | Two trees, far apart, both selected. Far apart on purpose: rotating a pair swings each around the midpoint, and close together the ghosts land on the originals and the frame shows nothing. |
| `rotating` | **The ghosts.** Two extra trees at the would-be positions while the originals stay put — the object does not move until the button comes up, exactly as the Lua state behaves. Captured after the *third* move: the first enters the rotate and the second only seeds the baseline angle (a zero rotation, whose ghosts sit on the originals). |
| `rotated` | The pair has actually swung. |

## brush-size-rust

Feature brushing fills unoccupied space, and Shift+wheel resizes its reach.

| screen | what it pins down |
| --- | --- |
| `brush-size-default` | Brush mode, Size 100. |
| `brush-size-enlarged` | Shift+wheel raised it to 264 — the panel's Size field follows the wheel. The scenario asserts a repeat default-size dab adds nothing over its existing feature, then checks the enlarged brush still produces a wider multi-feature scatter. |

## gallery-rust / gallery-pickers-rust

The Dev tab's **control gallery** — a kitchen sink holding every field type. It is
behind `SBC_DEV_PANEL=1`, so it neither ships in the tab bar nor appears in any
other scenario's screenshots (`just dev-panel` opens it by hand).

Each control reports the value it produced (`dev-fields: <field> = <value>` in the
log) and the scenario asserts on that. It has to: a **drag never fires a DOM
change**, so there is nothing else to observe.

| screen | what it pins down |
| --- | --- |
| `fields-at-rest` | One image of the **whole control set**: string (and empty string), numeric plain/bounded/3-decimal, boolean on and off, choice, colour, asset, and a group on one row. The cheapest way to see what everything looks like, and what a restyle would change. |
| `numeric-dragging` | Mid-drag on a numeric: the value moves (50 → 88) without the field ever entering text mode, and the pointer is pinned and hidden. |
| `choice-open` | The choice list, open, showing its items. |
| `fields-after-input` | After driving every control: string typed, numeric typed, bounded dragged, boolean toggled off, choice on "Second". |
| `colour-picker` | The colour modal the colour field opens (gradient, hue strip, preview, OK/Cancel). Full-frame — the modal is drawn beside the panel, outside this case's crop. |
| `colour-picked` / `colour-committed` | The gradient is **grabbed**, not clicked (mousedown starts it and the colour follows the pointer per tick), and OK commits a real value. |
| `asset-packs` | The asset picker opens on SpringBoard's **asset packs** (`core/`), not on a directory: a field's root is a place *inside* a pack. |
| `asset-in-pack` / `asset-back-at-packs` | Into the pack and back out with Up — each asserted to have actually redrawn the listing. Cells show the texture itself. |
| `asset-selected` / `asset-committed` | Picking commits an **asset path** (`core/cement_diffuse.png`), which is what a project stores — not a filesystem path. |
| `new-project`, `file-dialog` (+ `-closed`) | The two dialogs the toolbar opens, and Escape closing them. The file dialog's Up at its root does nothing, which is the bound it should have. |
| `no-tooltip` / `numeric-tooltip` / `tooltip-gone` | Hovering a control shows its tooltip, and moving away removes it. The only scenario with tooltips on — they follow the pointer, so every other run hides them (`SBC_HIDE_TOOLTIPS`). |

## cursortip-rust

Hovering a unit or feature shows a tooltip describing it.

| screen | what it pins down |
| --- | --- |
| `no-tooltip` | Empty ground: no tip. |
| `hover-tooltip` | Hovering the feature: the tip appears next to the cursor with its name and health. Asserted by counting the tip's near-black pixels, not by diffing — the map shimmers. |

The tip follows the cursor, so it would land in the middle of every other map
capture: the harness hides it (`SBC_HIDE_CURSORTIP`) and this scenario is the one
that asks for it back (`env=` on `@scenario`). Both frames are `park=False` — the
tip is drawn *at* the pointer, so parking it out of shot takes the subject away.

## native-dev-console-rust

The dev console, cleared first, so an empty log is the deterministic state; its
toolbar and F8 toggle are what the goldens pin down.
