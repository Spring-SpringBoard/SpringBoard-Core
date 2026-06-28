---
name: RmlUi side-branch survey
description: Inventory and comparison of the off-master RmlUi branches
---

# RmlUi side-branch survey

Factual inventory of the RmlUi work that exists on side branches, captured for
reference by [02-view.md](02-view.md). No code from these branches is merged into
`rust-wip`; this records what they contain and how they relate.

All measurements are against the common fork point **`d8cc6f2`** ("update BAR
engine to match & ids unique", 2024-05-17) — every branch below diverges from
master there. `test-engine/` (a vendored engine bundle present on two branches)
is excluded from line/file counts unless stated.

## Branch inventory

| Short name | Ref | Tip | Commits | First→last commit | LOC vs fork (excl. engine) |
|---|---|---|---|---|---|
| base | `origin/rmlui` | `6343459` "good base" | 2 | 2025-11-16 | +5,248 / −127 |
| local | `rmlui` (local only) | `29927f4` "good base" | 59 | 2025-11-05→11-16 | +5,265 / −129 |
| 01D5 | `origin/claude/fetch-rebase-rmlui-01D5pVN1phpcbVYpt5y4NUEB` | `8c1ae9e` | 13 | 2025-11-16→11-18 | +8,688 / −2,236 |
| claude | `origin/claude-rmlui` | `66c5b41` "wip" | 1 | 2025-11-20 | +7,680 / −878 |
| 0184 | `origin/claude/fetch-rebase-rmlui-0184nkrShRXMr9nYWayrEZ2w` | `68d803b` | 44 | 2025-11-16→11-17 | +7,259 / −562 |
| springboard | `origin/claude/springboard-rmlui-conversion-011CUooEurKLbWKUu8vygDUw` | `b063278` | 57 | 2025-11-05→11-07 | +4,080 / −31 |

`springboard` and `local` additionally bundle an 89 MB vendored `test-engine/`
(~223 files), which inflates their raw totals to +45,771 and +46,956 lines
respectively.

## Lineage

All six fork from master at `d8cc6f2`. Two ancestry chains, two independents:

- **base → 01D5** — 01D5 is built on top of `origin/rmlui`; it adds a layer (see below).
- **springboard → local** — `local` is `springboard` plus 2 commits (the dev-console commit, below).
- **claude** — independent, single squashed commit off the fork point.
- **0184** — independent, 44 commits off the fork point.

`base` and `springboard` have **byte-identical `scen_edit/` trees** despite no
shared history past the fork point — their editor code is the same body of work.
`springboard` differs from `base` only outside `scen_edit/` (the bundled engine
and map-handling removals).

## Commit-history shape

Objective commit-subject counts (subjects matching
`fix|bug|crash|error|broken|workaround|compat`):

| Branch | Commits | Fix/crash/compat-type subjects |
|---|---|---|
| base | 2 | 0 |
| claude | 1 | 0 |
| 01D5 | 13 | 0 |
| 0184 | 44 | 21 |
| springboard | 57 | 32 |

01D5's 13 commits are all "Refactor X to use MVC", ending with "Add comprehensive
MVC refactoring summary". `claude` is a single squashed `wip` commit (history
flattened). `0184` and `springboard` carry many incremental fix commits.

## Comparison matrices

Indices: [1] base, [2] local, [3] 01D5, [4] claude, [5] 0184, [6] springboard.
All exclude `test-engine/`.

### Files differing between branches (`scen_edit/view`)

| | [1] | [2] | [3] | [4] | [5] | [6] |
|---|---|---|---|---|---|---|
| **[1] base** | — | 3 | 54 | 87 | 56 | 12 |
| **[2] local** | 3 | — | 57 | 89 | 59 | 9 |
| **[3] 01D5** | 54 | 57 | — | 114 | 95 | 66 |
| **[4] claude** | 87 | 89 | 114 | — | 58 | 95 |
| **[5] 0184** | 56 | 59 | 95 | 58 | — | 67 |
| **[6] springboard** | 12 | 9 | 66 | 95 | 67 | — |

### Files both branches modify vs master (overlap; diagonal = own total)

| | [1] | [2] | [3] | [4] | [5] | [6] |
|---|---|---|---|---|---|---|
| **[1] base** | (50) | 50 | 50 | 37 | 43 | 41 |
| **[2] local** | 50 | (53) | 50 | 38 | 43 | 44 |
| **[3] 01D5** | 50 | 50 | (95) | 52 | 53 | 41 |
| **[4] claude** | 37 | 38 | 52 | (83) | 63 | 29 |
| **[5] 0184** | 43 | 43 | 53 | 63 | (70) | 34 |
| **[6] springboard** | 41 | 44 | 41 | 29 | 34 | (44) |

### LOC delta (row → column: +inserted / −deleted)

| row → col | [1] | [2] | [3] | [4] | [5] | [6] |
|---|---|---|---|---|---|---|
| **[1] base** | · | +17/−2 | +3759/−2428 | +4351/−2670 | +2688/−1112 | +115/−1187 |
| **[2] local** | +2/−17 | · | +3761/−2445 | +4352/−2686 | +2690/−1129 | +98/−1185 |
| **[3] 01D5** | +2428/−3759 | +2445/−3761 | · | +5915/−5565 | +5022/−4777 | +2543/−4946 |
| **[4] claude** | +2670/−4351 | +2686/−4352 | +5565/−5915 | · | +1799/−1904 | +2780/−5533 |
| **[5] 0184** | +1112/−2688 | +1129/−2690 | +4777/−5022 | +1904/−1799 | · | +1225/−3873 |
| **[6] springboard** | +1187/−115 | +1185/−98 | +4946/−2543 | +5533/−2780 | +3873/−1225 | · |

## Per-branch unique content

- **base** (`origin/rmlui`) — RmlUi foundation: `rmlui_builder/manager/component/
  components/fields`, `rmlui_field_compat.lua` (26 lines), `rmlui_dialogs/`
  (base_dialog, file_dialog, new_project_dialog), `rmlui_editor_base.lua`,
  `rmlui_editors/` stubs (heightmap, object, texture, trigger), `rmlui_floating/`
  (command_window, control_buttons, status_window, top_left_menu), 9 `.rml`,
  5 `.rcss`, `view.lua` +298. The branch (not the tip commit) also adds a
  smoke-test harness: `.github/workflows/smoke-test.yml`,
  `download-engine-for-testing.yml`, `SMOKE_TEST_STATUS.md`, `test-smoke.sh`.
- **01D5** — base + an MVC layer: `scen_edit/view/models/` (16 model files),
  full `rmlui_editors/` for water/sky/grass/metal/lighting/terrain_settings/
  texture/heightmap, `rmlui_general/` (players_window, scenario_info_view),
  `team_selector`, `bottom_bar`, `rcss/floating.rcss`.
- **claude** — independent foundation variant: `rmlui_fields.lua` (549 lines),
  `rmlui_field_compat.lua` (270), `generic_dialog.rml`, `ui_controls.lua`.
- **0184** — independent: GridView + RTT (render-to-texture) for the Objects
  tab, `ui_controls.lua`, a UI-abstraction layer (ActionButton, mode-aware
  controls, Chili/RmlUi bridging).
- **springboard** — `scen_edit/` identical to base; adds bundled `test-engine/`
  and map-handling removals.
- **local** — `springboard` + the "good base" dev-console commit (below).

## The "good base" commit (`6343459`)

The tip commit of `origin/rmlui` is **not** editor code. It is 8 files,
+1,184 / −97, a self-contained RmlUi dev-console widget plus bootstrap:

| File | Change |
|---|---|
| `LuaUI/main.lua` | +2 (include `rml_setup2.lua`) |
| `LuaUI/rml_setup2.lua` | +84 — RmlUi init: context/dp_ratio, font loading, cursor aliases (authored by engine devs lov + ChrisFloofyKitsune) |
| `LuaUI/rmlui/common.css` | +41 |
| `LuaUI/rmlui/dbg_dev_console.css` | +191 |
| `LuaUI/rmlui/dbg_dev_console.html` | +37 |
| `LuaUI/widgets/dbg_dev_console.lua` | modified |
| `LuaUI/widgets/dbg_dev_console_rmlui.lua` | +717 — interactive console (document load, element caching, `onclick`→widget-method binding, mouse routing, render loop, DOM batching) |
| `fonts/Poppins-Regular.ttf` | binary |

### This commit is already in `rust-wip`

All 8 files are present on `rust-wip`. `rml_setup2.lua`, both CSS files, the
font, and the `main.lua` include are **byte-identical**. The widget files are
**ahead** of `6343459` on `rust-wip`:

| File | rust-wip vs `6343459` |
|---|---|
| `LuaUI/widgets/dbg_dev_console_rmlui.lua` | +51 / −33 |
| `LuaUI/rmlui/dbg_dev_console.html` | +4 / −3 |
| `LuaUI/widgets/dbg_dev_console.lua` | +14 / −0 |

## `rust-wip` RmlUi state

`rust-wip`'s `scen_edit/view` RmlUi foundation derives from **claude**, not base:
`rmlui_field_compat.lua` is 274 lines (claude: 270; base: 26), and it carries
`generic_dialog.rml` + `ui_controls.lua` (claude signatures absent from base).

`scen_edit/view` files differing, `rust-wip` vs each branch: base 71, local 71,
01D5 97, claude 36, 0184 56, springboard 71. Relative to `rust-wip`, 01D5 has 36
files that are new (the `models/` + editor layer) and 41 that exist but differ;
0184 has 3 new / 40 differing; claude 0 new / 35 differing; base 9 new / 24
differing.

## Where the code lives

Canonical source is the branch refs above. Local checkouts are kept as git
worktrees under `~/worktrees/SBC.sdd/ui-branches/<short-name>/`.
