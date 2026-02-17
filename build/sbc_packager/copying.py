from __future__ import annotations

import shutil
from pathlib import Path

EXCLUDED_TOP_LEVEL: set[str] = {
    ".git",
    ".github",
    ".vscode",
    "build",
    "dist_cfg",
    "doc",
    "issues",
}

EXCLUDED_PATHS: set[str] = {
    ".gitignore",
    ".gitmodules",
}


def collect_generated_top_level_excludes(repo_root: Path, generated_paths: list[Path]) -> set[str]:
    excludes: set[str] = set()
    resolved_repo_root = repo_root.resolve()

    for generated_path in generated_paths:
        resolved_generated = generated_path.resolve()
        try:
            relative = resolved_generated.relative_to(resolved_repo_root)
        except ValueError:
            continue
        if relative.parts:
            excludes.add(relative.parts[0])

    return excludes


def copy_repo_filtered(source_root: Path, destination_root: Path, extra_top_level_excludes: set[str]) -> None:
    for entry in source_root.iterdir():
        relative_path = entry.relative_to(source_root).as_posix()
        if should_exclude(relative_path, extra_top_level_excludes):
            continue

        destination_entry = destination_root / entry.name
        if entry.is_dir():
            destination_entry.mkdir(parents=True, exist_ok=True)
            copy_tree_filtered(source_root, entry, destination_entry, extra_top_level_excludes)
            continue

        if entry.is_file():
            destination_entry.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entry, destination_entry)


def copy_tree_filtered(
    source_root: Path,
    source_dir: Path,
    destination_dir: Path,
    extra_top_level_excludes: set[str],
) -> None:
    for entry in source_dir.iterdir():
        relative_path = entry.relative_to(source_root).as_posix()
        if should_exclude(relative_path, extra_top_level_excludes):
            continue

        destination_entry = destination_dir / entry.name
        if entry.is_dir():
            destination_entry.mkdir(parents=True, exist_ok=True)
            copy_tree_filtered(source_root, entry, destination_entry, extra_top_level_excludes)
            continue

        if entry.is_file():
            destination_entry.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entry, destination_entry)


def should_exclude(relative_path: str, extra_top_level_excludes: set[str]) -> bool:
    top_level = relative_path.split("/", 1)[0]
    if top_level.startswith(".local-packaged-"):
        return True
    if top_level in EXCLUDED_TOP_LEVEL:
        return True
    if top_level in extra_top_level_excludes:
        return True
    return relative_path in EXCLUDED_PATHS
