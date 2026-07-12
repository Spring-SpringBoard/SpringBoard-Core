#!/usr/bin/env python3
"""What reference images exist, and which are still waiting on a human.

Run through `just goldens-status`.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from golden import GOLDEN_ROOT, STATUS_APPROVED, load_review  # noqa: E402


def main() -> int:
    pending = 0
    for case_dir in sorted(GOLDEN_ROOT.iterdir()):
        if not case_dir.is_dir():
            continue
        review = load_review(case_dir.name)
        shots = sorted(p.stem for p in case_dir.glob("*.png"))
        if not shots:
            continue
        approved = sum(
            1 for s in shots if review.get(s, {}).get("status") == STATUS_APPROVED
        )
        pending += len(shots) - approved
        print(f"{case_dir.name:26} {approved}/{len(shots)} approved")
        for shot in shots:
            if review.get(shot, {}).get("status") != STATUS_APPROVED:
                print(f"    ai-reviewed  {shot}")

    if pending:
        print(
            f"\n{pending} image(s) awaiting approval."
            "\nInspect them, then: just goldens-approve <case>"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
