#!/usr/bin/env python3
"""Promote ai-reviewed reference images to approved goldens.

Running this is the human OK. The agent never runs it.
"""

from __future__ import annotations

import sys

from golden import STATUS_APPROVED, load_review, review_path
import json


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: approve_goldens.py <case-name> [shot-name ...]", file=sys.stderr)
        return 1
    case, shots = argv[0], argv[1:]
    data = load_review(case)
    if not data:
        print(f"no review data for {case}", file=sys.stderr)
        return 1
    for name, entry in data.items():
        if shots and name not in shots:
            continue
        entry["status"] = STATUS_APPROVED
    review_path(case).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    print(f"approved {len(shots) or len(data)} image(s) for {case}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
