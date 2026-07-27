# Native E2E failure ledger

All failures from the 2026-07-27 sweep are resolved. The final `all` Rust UI
sweep completed successfully. Updated captures remain marked `ai-reviewed`;
approving them is deliberately a human action.

## Outstanding failures

None.

## Resolved

| Target | Resolution |
| --- | --- |
| `brush-size` | Root-coordinate mouse input now accounts for the Spring window origin; the enlarged brush behaves correctly. Recaptured for the versioned 1371px window height and rerun successfully. |
| `collision` | Current full-width collision form layout was reviewed; its old narrow-field references were stale. Recaptured and rerun successfully. |
| `cursortip` | Reviewed identical tooltip behaviour at the versioned 1371px window height. Recaptured and rerun successfully. |
| `project-status-bar` | Comparator now ignores one-channel alpha-compositing quantisation drift; the actual status surface otherwise matches exactly. Rerun successfully. |
| `def-grid`, `deselect`, `rotation` | Reviewed current behavior and recaptured for the versioned 1371px window geometry. |
| `selection` | Reviewed and recaptured for the versioned 1371px window geometry. A subsequent regression holds left during a box drag, right-clicks to cancel it, checks that the transient outline is gone, then completes a fresh box selection. |
| `feature-placement-actions` | Its panel-local visual comparison was using full-window coordinates; corrected crop coordinates now assert the Add → Brush change. |
| `gallery`, `gallery-dialogs`, `gallery-pickers`, `gallery-tooltips` | Reviewed the current fields, drag, dialogs, pickers, and tooltips; stale references were recaptured. |
| `native-dev-console` | Reviewed the current console/status presentation, including the live line count; stale references were recaptured. |
| `props-panel` | Form references were updated for full-width controls. The outside-drag assertion now unambiguously marks the releasing drag and tolerates only the documented live numeric glyph variation. |
| `units-panel` | Reviewed panel and world output; stale references were recaptured. |

The runner now finalizes each case independently, so `sbc-e2e run all` continues
after an assertion failure and reports every affected case.

## Manual review and deterministic coverage

All updated golden sets were reviewed as labeled contact sheets. Their state
sequences are coherent: placement counts, selection and drag states, collision
volume visibility, cursortips, picker navigation, dialogs, and console states.
That review caught one Props-form overflow (`Reclaim Time` running into its
value); it now ellipsizes rather than overlapping, and its targeted capture was
visually rechecked.

Fast regression tests now cover the harness behavior that formerly required a
large E2E sweep: root-coordinate translation, one-channel framebuffer noise,
and continuing after a golden finalization failure. The object scenarios retain
their domain-level deterministic assertions (commands, placed-object counts,
world positions, drag completion, and right-click cancellation of a rectangle
select) alongside their visual checks.
