#!/usr/bin/env python3
"""Black-box UI E2E driver for SBC."""

from __future__ import annotations

import argparse
import os
import sys

from cases import target_cases
from runner import E2ERun


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "target",
        nargs="?",
        default="chonsole",
        choices=("chonsole", "main-panel", "lighting-panel", "units-panel", "texture-panel", "dev-console", "teams-panel", "info-panel", "settings-panel", "props-panel"),
        help="E2E target to run.",
    )
    parser.add_argument(
        "--case",
        choices=("all", "lua", "rust"),
        default="all",
        help="Run one implementation or both.",
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

    failures = 0
    for case in target_cases(args.target, args.case):
        run = E2ERun(
            case,
            capture=args.capture,
            review_images=not args.no_review_images,
            image_workers=max(1, args.image_workers),
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
