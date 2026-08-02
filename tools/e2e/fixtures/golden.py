"""Golden-image comparison.

A screenshot test that only checks "the process did not crash" catches nothing
the log does not already catch. These references are checked into the repo, and
every run is compared against them pixel-exactly.

Provenance matters: an image is only a *golden* once a human has approved it.
Until then it is `ai-reviewed` — captured and inspected by the agent, which
records in `review.json` what it actually checked. Promote with
`just goldens-approve <case>`.

Determinism requirements for a capture (see `E2ERun.golden`):
  - the game is paused (SBC boots paused), so the map render does not move;
  - the cursor is parked away from the panel, since the engine draws it;
  - the capture is cropped to the region under test.
"""

import json
import shutil
from datetime import UTC, datetime
from pathlib import Path
from typing import NotRequired, TypedDict, cast

from PIL import Image, ImageChops

GOLDEN_ROOT = Path(__file__).resolve().parent / "goldens"

STATUS_AI = "ai-reviewed"
STATUS_APPROVED = "approved"


class ReviewEntry(TypedDict):
    status: str
    updated: NotRequired[str]
    notes: NotRequired[str]


type Review = dict[str, ReviewEntry]


def load_review(case_name: str) -> Review:
    path = review_path(case_name)
    if not path.is_file():
        return {}
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise RuntimeError(f"golden review must be an object: {path}")
    return cast("Review", value)


def record_review(case_name: str, shot_name: str, *, notes: str = "") -> None:
    """Mark an image as captured and inspected by the agent, not yet approved."""
    data = load_review(case_name)
    entry = data.get(shot_name, {"status": STATUS_AI})
    if entry.get("status") == STATUS_APPROVED:
        entry["status"] = STATUS_AI  # it changed; it needs looking at again
    else:
        entry["status"] = STATUS_AI
    entry["updated"] = datetime.now(UTC).isoformat(timespec="seconds")
    if notes:
        entry["notes"] = notes
    data[shot_name] = entry
    path = review_path(case_name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def approve_review(case_name: str, requested: set[str]) -> int:
    review = load_review(case_name)
    if not review:
        raise RuntimeError(f"no review data for {case_name}")
    names = requested or set(review)
    unknown = names.difference(review)
    if unknown:
        raise RuntimeError(f"unknown golden screenshots for {case_name}: {', '.join(sorted(unknown))}")
    for name in names:
        review[name]["status"] = STATUS_APPROVED
    review_path(case_name).write_text(json.dumps(review, indent=2, sort_keys=True) + "\n")
    return len(names)


class GoldenMismatchError(Exception):
    pass


def golden_path(case_name: str, shot_name: str) -> Path:
    return GOLDEN_ROOT / case_name / f"{shot_name}.png"


def differing_pixels(
    a: Path,
    b: Path,
    *,
    channel_tolerance: int = 1,
    ignored_bottom: int = 0,
) -> int | None:
    """Count pixels that differ by more than renderer quantisation noise.

    Alpha-blended RmlUi surfaces can shift every RGB channel by one when the
    engine's map framebuffer quantises differently between runs. That is not a
    visible UI change, but it formerly made a panel crop report every pixel as
    changed. Larger deltas remain exact and are subject to each check's normal
    pixel-count tolerance.
    """
    with Image.open(a) as first, Image.open(b) as second:
        first_rgba = first.convert("RGBA")
        second_rgba = second.convert("RGBA")
        if first_rgba.size != second_rgba.size:
            return None
        if ignored_bottom:
            bottom = max(0, first_rgba.height - ignored_bottom)
            first_rgba = first_rgba.crop((0, 0, first_rgba.width, bottom))
            second_rgba = second_rgba.crop((0, 0, second_rgba.width, bottom))
        difference = ImageChops.difference(first_rgba, second_rgba)
        return _count_pixels_over(difference, channel_tolerance)


def write_diff(golden: Path, actual: Path, out: Path) -> None:
    with Image.open(golden) as expected, Image.open(actual) as observed:
        ImageChops.difference(expected.convert("RGBA"), observed.convert("RGBA")).save(out)


def compare(
    case_name: str,
    shot_name: str,
    actual: Path,
    *,
    update: bool,
    tolerance: int = 0,
    ignored_bottom: int = 0,
) -> str:
    """Compare `actual` against its golden.

    Returns a short status string. Raises GoldenMismatchError on any pixel diff beyond
    `tolerance`, so a run fails loudly rather than leaving the difference in an
    artifact nobody opens.

    `tolerance` exists for one reason: the engine's map render is not bit-stable
    between runs -- something in the tree draw varies by a few dozen pixels frame
    to frame (measured 10-137 px over the full window; not wind, that was ruled
    out). A capture that includes the map cannot be pixel-exact. Panel-only crops
    *are* exact and must stay at 0. Keep any tolerance far below the size of a
    real regression: a missing ghost, box or panel is thousands of pixels.
    """
    golden = golden_path(case_name, shot_name)

    if update or not golden.exists():
        golden.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(actual, golden)
        record_review(case_name, shot_name)
        if update:
            return "captured (ai-reviewed pending)"
        raise GoldenMismatchError(
            f"no reference for {case_name}/{shot_name}; wrote {golden}. "
            f"Inspect it, record what you checked, then have it approved."
        )

    diff = differing_pixels(golden, actual, ignored_bottom=ignored_bottom)
    if diff == 0:
        return "match"
    if diff is not None and diff <= tolerance:
        return f"match ({diff} px within {tolerance} tolerance)"

    failed_dir = actual.parent / "golden-failures"
    failed_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(actual, failed_dir / f"{shot_name}.actual.png")
    if diff is not None:
        write_diff(golden, actual, failed_dir / f"{shot_name}.diff.png")
        raise GoldenMismatchError(f"{case_name}/{shot_name}: {diff} pixel(s) differ from golden; see {failed_dir}")
    raise GoldenMismatchError(
        f"{case_name}/{shot_name}: image is not comparable to the golden (size changed?); see {failed_dir}"
    )


def review_path(case_name: str) -> Path:
    return GOLDEN_ROOT / case_name / "review.json"


def _count_pixels_over(image: Image.Image, threshold: int) -> int:
    """Count pixels whose largest channel exceeds ``threshold``.

    The former Python loop inspected every RGBA tuple in a full engine frame.
    Reducing the channels with Pillow's C implementation retains the exact
    `max(channel) > threshold` predicate while making large golden comparisons
    cheap enough to keep the suite's visual coverage.
    """
    channels = image.split()
    maximum = channels[0]
    for channel in channels[1:]:
        maximum = ImageChops.lighter(maximum, channel)
    return sum(maximum.histogram()[threshold + 1 :])
