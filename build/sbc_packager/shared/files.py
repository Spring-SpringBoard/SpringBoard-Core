from __future__ import annotations

import shutil
from pathlib import Path

GAME_TOP_LEVEL: set[str] = {
    "Anims",
    "Gamedata",
    "LICENSE",
    "LuaHandler",
    "LuaRules",
    "LuaUI",
    "config",
    "exts",
    "fonts",
    "libs_sb",
    "modinfo.lua",
    "port_flags.json",
    "sb_settings.lua",
    "scen_edit",
    "shaders",
    "springboard",
    "templates",
    "triggers",
}


def collect_generated_top_level_excludes(repo_root: Path, generated_paths: list[Path]) -> set[str]:
    excludes: set[str] = set()
    resolved_repo_root = repo_root.resolve()
    for generated_path in generated_paths:
        try:
            relative = generated_path.resolve().relative_to(resolved_repo_root)
        except ValueError:
            continue
        if relative.parts:
            excludes.add(relative.parts[0])
    return excludes


def copy_repo_filtered(source_root: Path, destination_root: Path, extra_top_level_excludes: set[str]) -> None:
    for entry in sorted(source_root.iterdir(), key=lambda path: path.name):
        if entry.name not in GAME_TOP_LEVEL or entry.name in extra_top_level_excludes:
            continue
        destination = destination_root / entry.name
        if entry.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
            copy_tree(entry, destination)
        elif entry.is_file():
            shutil.copy2(entry, destination)


def copy_tree(source_dir: Path, destination_dir: Path) -> None:
    for entry in sorted(source_dir.iterdir(), key=lambda path: path.name):
        destination = destination_dir / entry.name
        if entry.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
            copy_tree(entry, destination)
        elif entry.is_file():
            shutil.copy2(entry, destination)
