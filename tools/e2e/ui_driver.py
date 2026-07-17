#!/usr/bin/env python3
"""Black-box UI E2E driver for SBC."""

from __future__ import annotations

import argparse
import os
import sys

from cases import TARGETS, select_cases, target_cases
from runner import E2ERun


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "target",
        nargs="?",
        default="chonsole",
        choices=(*TARGETS, "all"),
        help="E2E target to run, or `all` to select purely by tag.",
    )
    parser.add_argument(
        "--tag",
        action="append",
        default=[],
        metavar="TAG",
        help=(
            "Only run cases carrying this tag; repeat for AND. "
            "Tags: target:<name>, ui:chili|rmlui|rust, chonsole:lua|rust. "
            "Example: --tag ui:rust"
        ),
    )
    parser.add_argument(
        "--update-golden",
        action="store_true",
        help="Rewrite golden images from this run. Look at the diff before committing.",
    )
    parser.add_argument(
        "--stage-golden",
        action="store_true",
        help="Capture golden candidates without comparing or writing references.",
    )
    parser.add_argument(
        "--keep-open",
        action="store_true",
        help="Leave the editor running after the scripted scenario.",
    )
    parser.add_argument(
        "--capture",
        choices=("raw", "png"),
        default="raw",
        help="raw captures XWD during interaction and converts later; png encodes immediately.",
    )
    parser.add_argument(
        "--no-review-images",
        action="store_true",
        help="Skip PNG conversion and contact sheet generation; keep raw .xwd captures.",
    )
    parser.add_argument(
        "--image-workers",
        type=int,
        default=min(4, os.cpu_count() or 1),
        help="Parallel workers for converting raw screenshots to PNG review images.",
    )
    args = parser.parse_args(argv)
    if args.update_golden and args.stage_golden:
        parser.error("--update-golden and --stage-golden are mutually exclusive")

    if args.tag or args.target == "all":
        cases = select_cases([args.target], args.tag)
        if not cases:
            print(f"no cases match {args.target} {args.tag}", file=sys.stderr)
            return 1
    else:
        cases = target_cases(args.target)

    failures = 0
    for case in cases:
        run = E2ERun(
            case,
            capture=args.capture,
            review_images=not args.no_review_images,
            image_workers=max(1, args.image_workers),
            update_golden=args.update_golden,
            stage_goldens=args.stage_golden,
        )
        print(f"run.md: {run.run_md}", flush=True)
        try:
            run.launch()
            run.run_scenario()
            run.finish("complete")
        except Exception as err:
            failures += 1
            run.event("error", error=str(err))
            run.finish("failed", error=str(err))
            print(f"ERROR: {case.name}: {err}", file=sys.stderr)
        finally:
            if not args.keep_open:
                run.stop()
                run.cleanup_write_dir()
            print(f"run.md: {run.run_md}", flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
