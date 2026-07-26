#!/usr/bin/env python3
"""Write a tree-structured, line-counted diff between two Git worktrees.

Example:
    tools/dev/worktree_delta.py \
        /home/gajop/worktrees/SBC.sdd/SBC-rust-stable.sdd \
        /home/gajop/projects/spring-projects/SBC.sdd \
        --output docs/porting/rust-wip-vs-rust-stable.md

The report compares the worktrees' HEAD commits.  It deliberately excludes
uncommitted changes so a committed report can be reproduced exactly.
"""

from __future__ import annotations

import argparse
import subprocess
from collections import defaultdict
from pathlib import Path


def git(worktree: Path, *args: str) -> str:
    return subprocess.run(
        ("git", "-C", str(worktree), *args),
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def worktree_path(value: str) -> Path:
    path = Path(value).resolve()
    try:
        return Path(git(path, "rev-parse", "--show-toplevel").strip())
    except subprocess.CalledProcessError as error:
        raise argparse.ArgumentTypeError(f"not a Git worktree: {path}") from error


def diff_entries(baseline: Path, candidate: Path) -> list[tuple[str, int | None, int | None]]:
    baseline_rev = git(baseline, "rev-parse", "HEAD").strip()
    candidate_rev = git(candidate, "rev-parse", "HEAD").strip()
    output = git(
        candidate,
        "diff",
        "--numstat",
        "--find-renames",
        baseline_rev,
        candidate_rev,
    )
    entries = []
    for line in output.splitlines():
        added, removed, *paths = line.split("\t")
        path = paths[-1]
        entries.append(
            (
                path,
                None if added == "-" else int(added),
                None if removed == "-" else int(removed),
            )
        )
    return entries


def render_tree(entries: list[tuple[str, int | None, int | None]]) -> list[str]:
    tree: dict[str, dict] = {}
    for path, added, removed in entries:
        node = tree
        for component in path.split("/")[:-1]:
            node = node.setdefault(component, {})
        node[path.split("/")[-1]] = (added, removed)

    lines: list[str] = []

    def visit(node: dict, depth: int) -> None:
        for name, value in sorted(node.items()):
            indent = "  " * depth
            if isinstance(value, dict):
                lines.append(f"{indent}- {name}/")
                visit(value, depth + 1)
            else:
                added, removed = value
                counts = "binary" if added is None else f"+{added} / -{removed}"
                lines.append(f"{indent}- `{name}` ({counts})")

    visit(tree, 0)
    return lines


def render_report(baseline: Path, candidate: Path) -> str:
    baseline_rev = git(baseline, "rev-parse", "HEAD").strip()
    candidate_rev = git(candidate, "rev-parse", "HEAD").strip()
    entries = diff_entries(baseline, candidate)
    added = sum(value for _, value, _ in entries if value is not None)
    removed = sum(value for _, _, value in entries if value is not None)
    binary_files = sum(1 for _, value, _ in entries if value is None)

    lines = [
        "# rust-wip vs rust-stable delta",
        "",
        "This is a committed-HEAD comparison; it intentionally excludes uncommitted worktree changes.",
        "",
        "| Side | Worktree | Commit |",
        "| --- | --- | --- |",
        f"| Baseline | `{baseline}` | `{baseline_rev}` |",
        f"| Candidate | `{candidate}` | `{candidate_rev}` |",
        "",
        "## Totals",
        "",
        f"- Files changed: {len(entries)}",
        f"- Lines added: {added}",
        f"- Lines removed: {removed}",
        f"- Total LOC changed: {added + removed}",
        f"- Binary files changed: {binary_files}",
        "",
        "## Changed files",
        "",
        *render_tree(entries),
        "",
        "Regenerate with `tools/dev/worktree_delta.py BASELINE_WORKTREE CANDIDATE_WORKTREE --output OUTPUT_FILE`.",
        "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=worktree_path, help="worktree to compare from")
    parser.add_argument("candidate", type=worktree_path, help="worktree to compare to")
    parser.add_argument("--output", "-o", type=Path, help="write the Markdown report here")
    args = parser.parse_args()

    report = render_report(args.baseline, args.candidate)
    if args.output:
        args.output.write_text(report)
    else:
        print(report, end="")


if __name__ == "__main__":
    main()
