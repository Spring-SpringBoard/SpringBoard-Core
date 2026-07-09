# SpringBoard RmlUi port — status

Goal: make the **Lua + RmlUi** UI functionally equivalent and visually close to the
**Lua + ChiliUI** UI.

Mode is selected by `port_flags.json` (`ui: chili | rmlui`), exposed to Lua as
`SB.useRmlUi`. Engine-side RmlUi bugs are fixed directly in `spring-bar` and
rebuilt — not worked around.

## How to run

```bash
just run config/luaui-chili.json     # Chili (baseline)
just run config/luaui-rmlui.json     # RmlUi (the port)

just test-e2e <target> '--case rust' # RmlUi only ("lua" = Chili baseline)
just test-e2e <target>               # both
```

E2E targets: `chonsole`, `main-panel`, `units-panel`, `texture-panel`,
`lighting-panel`, `dev-console`, `teams-panel`, `settings-panel`, `info-panel`.

The harness (`tools/e2e/`) drives the real window with xdotool and writes
screenshots + logs to `artifacts/ui-e2e/<run>/`. **Screenshots are the source of
truth.** `infolog.txt` is only trustworthy because `LogFlushLevel=0` is set in
`tools/dev/springsettings.cfg`; without it the engine buffers and post-boot
errors never appear.

Engine rebuild:
```bash
cd ../spring-bar
./docker-build-v2/build.sh --compile linux -j 4
./docker-build-v2/build.sh --compile linux --target install -j 4
```

## Open issues

Numbers are stable ids; add new ones at the end.

| # | Issue | Status |
|---|---|---|
| O1 | Dialogs cannot be dragged | **Fixed.** `.dialog-header` has `drag: drag`; `RmlUiComponent` moves the box. |
| O2 | Dev console multi-line selection | **Fixed** (line-range). RmlUi cannot select text across elements and each log line is its own element, so whole lines are selected: drag to highlight, Ctrl+A all, Ctrl+C copies via `Spring.SetClipboard`. Character-level selection would need the log to be one text element (losing per-line colour). |
| O3 | Texture paint "Add" showed no materials | **Fixed.** Three stacked bugs: the picker's grid rendered into the *main* document; item tooltips injected raw Spring colour codes into the `title` attribute and truncated the DOM after the first cell; the label needed normal flow. |
| O4 | Map Settings texture options were inert checkboxes | **Fixed.** RmlUi marks a checkbox checked by the *presence* of the `checked` attribute (set to `""` on click); the handler compared it to `"checked"`, so every checkbox read false. Enabling e.g. Specular now opens the texture dialog. |
| O5 | Colour picker OK breaks the colour control | **Not reproducible** on the current build (see `lighting-panel` e2e: OK, then the swatch re-opens the picker). It was most likely a symptom of the stale-element crash path, now guarded engine-side. Reopen with a repro if it recurs. |
| O6 | Misc → Info: stray colour after editing text | **Not reproduced.** The `info-panel` e2e target does exactly this (pick a colour in Lighting → Misc → Info → type) and shows no colour. The grey box that does appear is the *engine's* tooltip console (`InputReceiver::GetTooltip` → "No tooltip defined"), not SBC. Reopen with a repro. |
| O7 | No FPS / memory status in RmlUi | **Fixed.** The template used `data-bind`, which is not an RmlUi data view (valid: `attr attrif class if visible rml style text value checked alias for`). Now `data-rml`, and it shows `FPS n \| Memory n MB \| Video memory: n/n MB`. |
| O8 | RTT thumbnail framing | Cosmetic, left at `×1.5` scale as agreed. |
| O9 | The generic texture dialog is cramped | Fields overlap the footer at the fixed 400×400 `.dialog` size, and its title reads "Dialog". Cosmetic. |

## Chili in RmlUi mode

`GridView` no longer builds any Chili controls when `SB.useRmlUi`: no `LayoutPanel`,
`ScrollPanel`, holder `Control`, `ImageListView`, and no `Control`/`Image`/`Label`
per cell — items are plain tables. `PlayersWindow` likewise builds no `StackPanel`.

Note `self.items` and Chili's `layoutPanel.children` were *different object sets*,
which caused a string of bugs; RmlUi now filters by predicate (`_RmlUiItemVisible`)
and routes selection by the item object, never by layout-panel membership.

**Zero Chili controls are constructed in RmlUi mode**, verified rather than assumed:
wrapping every Chili class' `New` in `exports.lua` and replaying all e2e targets
reports no constructions. That audit found five leftovers, now fixed:

| Where | What it built |
|---|---|
| `TabbedWindow` / `MainWindowPanel` | the whole Chili right panel, alongside `springboard_main.rml` |
| `libs_sb/chonsole` `ui_chonsole.lua` | `RemoveWidget` without `return`, so it built its EditBox/ScrollPanel/Label anyway |
| `numeric_field.lua` | drag-overlay `Image`s at file scope |
| `collision_window.lua` | `Button:New` instead of `EditorButton` |
| `gui_chili_selections_and_cursortip.lua` | no RmlUi guard at all |

The cursortip is now `LuaUI/widgets/gui_rmlui_cursortip.lua` (target: `cursortip`).
It picks with `Spring.GetUnitsInScreenRectangle` / `GetFeaturesInScreenRectangle`,
*not* `TraceScreenRay`: the engine's GUI ray never reports SpringBoard's features
(`Spring.GetCurrentTooltip()` reads "No tooltip defined" while hovering a tree), so
the Chili tooltip never showed them either. Its document covers the screen, so it
sets `pointer-events: none` to keep map clicks working.

Widget-level guards must read `Spring.GetGameRulesParam("useRml")`, not
`WG.SB.useRmlUi` — `WG.SB` does not exist yet when a layer-0 widget initializes.

What is left is the framework itself: `api_sb_chili.lua` still creates
`Chili.Screen0`, but it stays empty, so it neither draws nor takes input, and the
Chili class definitions the shared editors reference for their Chili branch.

## Known engine constraints (learned the hard way)

- **RmlUi blends with premultiplied alpha** (`glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)`).
  Translucent PNGs must store `RGB = colour × alpha`. A *black* overlay works either
  way (`0 × a == 0`); a *white* one paints opaque white everywhere. This was the
  colour-picker SV square bug.
- **A data model only re-evaluates its bindings on the next context update.** A
  `data-if` therefore lags a frame or more; for something that must appear the frame
  the cursor lands on it (the cursor tooltip), toggle a CSS class with
  `Element:SetClass` instead.
- **`Spring.GetMouseState()`'s button flags read as released while RmlUi holds the
  mouse capture.** Any drag must take pressed-state from RmlUi's own
  `mousedown`/`mouseup` and use `Spring.GetMouseState` only for the cursor position.
- **Never rebuild the DOM while RmlUi is dispatching an event** — it frees the very
  elements being processed (ASAN use-after-poison). Defer with `SB.delay`.
- **RCSS has no `!important`.** A one-class rule ties with other one-class rules and
  loses on declaration order; raise specificity with compound selectors.
- **`display: flex` on a text-bearing element makes RmlUi drop the text node.** Use
  `text-align` + `line-height` to centre a label.
- Dropdown options are `selectbox option`; there is **no `selectoption` element**.
  The current option carries `:checked`.
- `<texture src="!...">` renders any Lua texture (incl. RTT) — resolved by
  `ParseTextureImage`, the same resolver as `gl.Texture()`.
- `self.items` and Chili's `layoutPanel.children` are **different object sets** under
  RmlUi. Never key visibility/selection off layoutPanel membership.
- Several RmlUi code paths were gated on `if self.layoutPanel` — which is **always**
  truthy (`GridView.init` always builds it), so they were dead. Gate on `SB.useRmlUi`.
- Directly-registered RmlUi event callbacks run with a stripped environment: globals
  like `SB` are not visible. Reference only upvalues, or call a method.
- A checkbox is checked when the `checked` attribute is **present** (RmlUi sets it to
  `""`). Use `HasAttribute("checked")`, never `GetAttribute(...) == "checked"`.
- Data views are `attr attrif class if visible rml style text value checked alias
  for`. There is no `data-bind`; a wrong name silently binds nothing.
- Never put raw Spring markup (colour codes `\255rgb`, `\b`, newlines) into an
  attribute: it corrupts the tag and RmlUi terminates the element early.
- Two Lua handles to the same `Rml::Element` are not necessarily `==`. Do not compare
  elements for identity; hit-test by geometry or compare ids.
- Lua has no `Element:SetProperty`; use `element.style["left"] = "10px"`.
- An inline `style` beats stylesheets, so an inline `display` will defeat
  `.something.hidden { display: none }`.
- A drag warps the cursor, so the mouse release usually lands on a *different*
  element than the one that started the drag. Bind a document-level `mouseup`.

## Engine changes made for this port (`spring-bar`)

- `SolLuaPlugin` tracks live `Rml::Element`s (`EVT_ELEMENT` +
  `OnElementCreate`/`OnElementDestroy`) and exposes `IsSolLuaElementAlive()`.
  `SetClass`, `SetAttribute` and the `inner_rml` getter/setter are guarded with it,
  so a stale Lua element reference is a no-op instead of a use-after-free. The
  lookup compares pointer values and never dereferences, so it is safe on a
  dangling pointer.
- Earlier fixes carried in this work stream: `SolLuaPlugin` shutdown iteration,
  GL3 renderer `PopLayer`, `Element:SetAttribute` string ownership.

## Verified

All targets run clean in **both** modes (`--case rust` = RmlUi, `--case lua` = Chili):
0 errors, 0 ASAN crashes, no leaked `/tmp/sbc-*` write dirs.

## Done

- Grid rendering (`GridView:_UpdateRmlUiGrid` was called in 9 places and defined
  nowhere), selection, filtering, `+` add-item.
- AssetView `pathNav`, texture picker, brush picker, material browser.
- 3D unit/feature previews via Lua RTT textures + the `<texture>` element.
- Numeric fields: click-to-edit (button hides), click-and-drag.
- Colour picker: correct HSV square, click and drag.
- Combobox option spacing + hover; tab label centring; checkbox spacing.
- Dev console renders real log lines (was showing `Test line 1/2/3`).
- Teams list renders (was Chili-only); add/remove/edit wired.
- Object properties window populated (`v[name]` → `v[tkey]` — every table-derived
  field was reading `nil`).
- Crashes fixed: grid `_UpdateRmlUiGrid`, search `self.search` nil, add-teams
  use-after-free, `SetClass`/`inner_rml` on stale elements.
- Numeric drag no longer sticks: the release lands on a *different* numeric button,
  whose handler used to steal and clear the shared active-drag slot, freezing the
  value and leaving the `.dragging` outline on screen.
- Dialogs draggable; dev console line selection + copy; status window (FPS/memory);
  checkboxes toggle; material picker lists materials; asset buttons restyled.
- Grids build no Chili controls in RmlUi mode.

## Harness / disk

`run_sbc.prepare()` copies the repo into a fresh `/tmp/sbc-*` game dir per run.
It used to copy `artifacts/` too (multi-GB, and growing each run) and never clean
up — that reached **405 GB**. Now: `artifacts` and `.venv` are excluded from the
copy *and* from `springignore.txt` (the engine was VFS-scanning them on every
launch, which is why boot was slow), raw `.xwd` captures are dropped once
converted to PNG, and the temp write dir is removed at the end of each run.
A run is now ~4 MB.
