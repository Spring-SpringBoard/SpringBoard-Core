# rust-wip vs rust-stable delta

This is a committed-HEAD comparison; it intentionally excludes uncommitted worktree changes.

| Side | Worktree | Commit |
| --- | --- | --- |
| Baseline | `/home/gajop/worktrees/SBC.sdd/SBC-rust-stable.sdd` | `f906b152d2276a507a7b63563a7879a828cc94fc` |
| Candidate | `/home/gajop/projects/spring-projects/SBC.sdd` | `1cb079a76c88b82f6daea89b1c237597d35e7be2` |

## Totals

- Files changed: 647
- Lines added: 53531
- Lines removed: 5314
- Total LOC changed: 58845
- Binary files changed: 80

## Top-level areas

| Path | Files | Added | Removed | LOC changed | Binary |
| --- | ---: | ---: | ---: | ---: | ---: |
| `(repository root)` | 10 | 512 | 16 | 528 | 0 |
| `.github/` | 3 | 282 | 117 | 399 | 0 |
| `LuaRules/` | 3 | 58 | 38 | 96 | 0 |
| `LuaUI/` | 23 | 2630 | 767 | 3397 | 3 |
| `build/` | 26 | 663 | 1051 | 1714 | 0 |
| `config/` | 7 | 60 | 0 | 60 | 0 |
| `dist_cfg/` | 2 | 24 | 106 | 130 | 0 |
| `docs/` | 18 | 1620 | 300 | 1920 | 0 |
| `fonts/` | 1 | 0 | 0 | 0 | 1 |
| `libs_sb/` | 2 | 2 | 2 | 4 | 0 |
| `native/` | 292 | 31079 | 384 | 31463 | 0 |
| `scen_edit/` | 100 | 8940 | 2031 | 10971 | 0 |
| `shaders/` | 1 | 5 | 1 | 6 | 0 |
| `tools/` | 159 | 7656 | 501 | 8157 | 76 |

## Native Rust subsystems

| Path | Files | Added | Removed | LOC changed | Binary |
| --- | ---: | ---: | ---: | ---: | ---: |
| `native/src/sbc/ (root)` | 6 | 610 | 1 | 611 | 0 |
| `native/src/sbc/actions/` | 8 | 760 | 0 | 760 | 0 |
| `native/src/sbc/areas/` | 3 | 104 | 0 | 104 | 0 |
| `native/src/sbc/chonsole/` | 19 | 3736 | 0 | 3736 | 0 |
| `native/src/sbc/command_system/` | 9 | 245 | 35 | 280 | 0 |
| `native/src/sbc/control/` | 15 | 815 | 0 | 815 | 0 |
| `native/src/sbc/dev/` | 2 | 221 | 0 | 221 | 0 |
| `native/src/sbc/devconsole/` | 10 | 2246 | 0 | 2246 | 0 |
| `native/src/sbc/grass/` | 8 | 285 | 12 | 297 | 0 |
| `native/src/sbc/heightmap/` | 14 | 535 | 45 | 580 | 0 |
| `native/src/sbc/log/` | 1 | 16 | 1 | 17 | 0 |
| `native/src/sbc/map_settings/` | 25 | 1455 | 26 | 1481 | 0 |
| `native/src/sbc/metal/` | 8 | 267 | 12 | 279 | 0 |
| `native/src/sbc/notifications/` | 2 | 172 | 0 | 172 | 0 |
| `native/src/sbc/objects/` | 33 | 4018 | 80 | 4098 | 0 |
| `native/src/sbc/panels/` | 47 | 9044 | 0 | 9044 | 0 |
| `native/src/sbc/project/` | 30 | 1513 | 82 | 1595 | 0 |
| `native/src/sbc/render/` | 2 | 151 | 0 | 151 | 0 |
| `native/src/sbc/states/` | 14 | 2425 | 0 | 2425 | 0 |
| `native/src/sbc/teams/` | 10 | 540 | 14 | 554 | 0 |
| `native/src/sbc/tests/` | 1 | 4 | 0 | 4 | 0 |
| `native/src/sbc/textures/` | 21 | 1677 | 64 | 1741 | 0 |

For the complete, aligned file list, use Git directly:

`git -C /home/gajop/projects/spring-projects/SBC.sdd diff --stat f906b152d2276a507a7b63563a7879a828cc94fc 1cb079a76c88b82f6daea89b1c237597d35e7be2`

Regenerate with `tools/dev/worktree_delta.py BASELINE_WORKTREE CANDIDATE_WORKTREE --output OUTPUT_FILE`.
