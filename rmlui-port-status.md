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
`lighting-panel`, `dev-console`, `teams-panel`.

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

| # | Issue | Notes |
|---|---|---|
| O1 | **Dialogs cannot be dragged.** They should be. | Needs a titlebar drag handler on the RmlUi dialog documents. |
| O2 | **Dev console multi-line selection doesn't work.** | Important. May not be supported by RmlUi's text elements at all — investigate whether an engine change is needed. Tracked, not yet attempted. |
| O3 | **Texture paint "Add" gives no material selection.** | Clicking Add to add a new paint texture shows nothing to select from. The add flow reaches `GetNewBrush`, but the material picker list is empty. |
| O4 | **Map Settings texture options are plain checkboxes.** | e.g. `specular` should let you *specify a texture* when enabled, not just toggle a bool. |
| O5 | **Colour picker OK breaks the editor's colour control.** | After confirming a colour, the editor's colour swatch button can no longer be clicked. Almost certainly the dialog leaves a stale element / unremoved listener, or the modal isn't fully torn down. |
| O6 | **Misc → Info: editing text shows a stray colour** from a previous step (lighting colour?). | Some colour state is leaking across editors. |
| O7 | **No FPS / memory / status readout in RmlUi mode.** | The status window is not ported. |
| O8 | RTT thumbnails: model framing inside the preview could be tighter. | Cosmetic; scale is currently `×1.5`. |

## Known engine constraints (learned the hard way)

- **RmlUi blends with premultiplied alpha** (`glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)`).
  Translucent PNGs must store `RGB = colour × alpha`. A *black* overlay works either
  way (`0 × a == 0`); a *white* one paints opaque white everywhere. This was the
  colour-picker SV square bug.
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

## Engine changes made for this port (`spring-bar`)

- `SolLuaPlugin` tracks live `Rml::Element`s (`EVT_ELEMENT` +
  `OnElementCreate`/`OnElementDestroy`) and exposes `IsSolLuaElementAlive()`.
  `SetClass`, `SetAttribute` and the `inner_rml` getter/setter are guarded with it,
  so a stale Lua element reference is a no-op instead of a use-after-free. The
  lookup compares pointer values and never dereferences, so it is safe on a
  dangling pointer.
- Earlier fixes carried in this work stream: `SolLuaPlugin` shutdown iteration,
  GL3 renderer `PopLayer`, `Element:SetAttribute` string ownership.

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

## Harness / disk

`run_sbc.prepare()` copies the repo into a fresh `/tmp/sbc-*` game dir per run.
It used to copy `artifacts/` too (multi-GB, and growing each run) and never clean
up — that reached **405 GB**. Now: `artifacts` and `.venv` are excluded from the
copy *and* from `springignore.txt` (the engine was VFS-scanning them on every
launch, which is why boot was slow), raw `.xwd` captures are dropped once
converted to PNG, and the temp write dir is removed at the end of each run.
A run is now ~4 MB.
