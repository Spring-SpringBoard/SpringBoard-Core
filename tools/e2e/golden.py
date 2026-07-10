"""Golden-image comparison.

A screenshot test that only checks "the process did not crash" catches nothing
the log does not already catch. These references are checked into the repo, and
every run is compared against them pixel-exactly.

Provenance matters: an image is only a *golden* once a human has approved it.
Until then it is `ai-reviewed` — captured and inspected by the agent, which
records in `review.json` what it actually checked. Promote with
`tools/e2e/approve_goldens.py <case>` (that act is the human OK).

Determinism requirements for a capture (see `E2ERun.golden`):
  - the game is paused (SBC boots paused), so the map render does not move;
  - the cursor is parked away from the panel, since the engine draws it;
  - the capture is cropped to the region under test.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

from process import run

GOLDEN_ROOT = Path(__file__).resolve().parent / "golden"

STATUS_AI = "ai-reviewed"
STATUS_APPROVED = "approved"


def review_path(case_name: str) -> Path:
    return GOLDEN_ROOT / case_name / "review.json"


def load_review(case_name: str) -> dict:
    path = review_path(case_name)
    return json.loads(path.read_text()) if path.is_file() else {}


def record_review(case_name: str, shot_name: str, *, notes: str = "") -> None:
    """Mark an image as captured and inspected by the agent, not yet approved."""
    data = load_review(case_name)
    entry = data.get(shot_name, {})
    if entry.get("status") == STATUS_APPROVED:
        entry["status"] = STATUS_AI  # it changed; it needs looking at again
    else:
        entry["status"] = STATUS_AI
    entry["updated"] = datetime.now().isoformat(timespec="seconds")
    if notes:
        entry["notes"] = notes
    data[shot_name] = entry
    path = review_path(case_name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


class GoldenMismatch(Exception):
    pass


def golden_path(case_name: str, shot_name: str) -> Path:
    return GOLDEN_ROOT / case_name / f"{shot_name}.png"


def differing_pixels(a: Path, b: Path) -> int | None:
    """Number of differing pixels, or None if the images are not comparable
    (different geometry)."""
    result = run(
        "compare", "-metric", "AE", str(a), str(b), "null:", check=False
    )
    # `compare` writes the metric to stderr and exits 1 when images differ, 2
    # when they cannot be compared at all.
    if result.returncode == 2:
        return None
    text = (result.stderr or "").strip().split()
    if not text:
        return None
    try:
        return int(float(text[0]))
    except ValueError:
        return None


def write_diff(golden: Path, actual: Path, out: Path) -> None:
    run("compare", str(golden), str(actual), str(out), check=False)


def compare(case_name: str, shot_name: str, actual: Path, *, update: bool) -> str:
    """Compare `actual` against its golden.

    Returns a short status string. Raises GoldenMismatch on any pixel diff, so a
    run fails loudly rather than leaving the difference in an artifact nobody
    opens.
    """
    golden = golden_path(case_name, shot_name)

    if update or not golden.exists():
        golden.parent.mkdir(parents=True, exist_ok=True)
        run("convert", str(actual), str(golden), check=True)
        record_review(case_name, shot_name)
        if update:
            return "captured (ai-reviewed pending)"
        raise GoldenMismatch(
            f"no reference for {case_name}/{shot_name}; wrote {golden}. "
            f"Inspect it, record what you checked, then have it approved."
        )

    diff = differing_pixels(golden, actual)
    if diff == 0:
        return "match"

    failed_dir = actual.parent / "golden-failures"
    failed_dir.mkdir(parents=True, exist_ok=True)
    run("convert", str(actual), str(failed_dir / f"{shot_name}.actual.png"), check=True)
    if diff is not None:
        write_diff(golden, actual, failed_dir / f"{shot_name}.diff.png")
        raise GoldenMismatch(
            f"{case_name}/{shot_name}: {diff} pixel(s) differ from golden; "
            f"see {failed_dir}"
        )
    raise GoldenMismatch(
        f"{case_name}/{shot_name}: image is not comparable to the golden "
        f"(size changed?); see {failed_dir}"
    )
