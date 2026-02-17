from __future__ import annotations

import re
import shutil
from pathlib import Path
from typing import Annotated, Literal

import typer

from .copying import collect_generated_top_level_excludes, copy_repo_filtered
from .json_io import read_json_dict, write_json_dict
from .models import DistConfig, EngineResource, PackageAssetsMeta, SetupConfig
from .rapid_alias import write_rapid_alias_metadata

app = typer.Typer(add_completion=False, no_args_is_help=True)


@app.command(name="prepare")
def prepare_command(
    repo_root: Annotated[Path, typer.Option(..., "--repo-root", exists=True, file_okay=False)],
    config_in: Annotated[Path, typer.Option(..., "--config-in", exists=True, dir_okay=False)],
    config_out: Annotated[Path, typer.Option(..., "--config-out")],
    files_dir: Annotated[Path, typer.Option(..., "--files-dir")],
    meta_out: Annotated[Path, typer.Option(..., "--meta-out")],
    git_hash: Annotated[str, typer.Option(..., "--git-hash")],
    platform: Annotated[str, typer.Option(..., "--platform")],
    linux_setup_id: Annotated[str, typer.Option("--linux-setup-id")] = "latest-linux",
    windows_setup_id: Annotated[str, typer.Option("--windows-setup-id")] = "latest-win",
) -> None:
    prepare_packaged_assets(
        repo_root=repo_root,
        config_in=config_in,
        config_out=config_out,
        files_dir=files_dir,
        meta_out=meta_out,
        git_hash=git_hash,
        platform=platform,
        linux_setup_id=linux_setup_id,
        windows_setup_id=windows_setup_id,
    )


def prepare_packaged_assets(
    repo_root: Path,
    config_in: Path,
    config_out: Path,
    files_dir: Path,
    meta_out: Path,
    git_hash: str,
    platform: str,
    linux_setup_id: str,
    windows_setup_id: str,
) -> None:
    resolved_repo_root = repo_root.resolve()
    resolved_config_in = config_in.resolve()
    resolved_config_out = config_out.resolve()
    resolved_files_dir = files_dir.resolve()
    resolved_meta_out = meta_out.resolve()

    normalized_platform = normalize_platform(platform)
    game_name = resolve_game_name_from_modinfo(resolved_repo_root, git_hash)

    config = DistConfig.model_validate(read_json_dict(resolved_config_in))
    selected_setup_id = linux_setup_id if normalized_platform == "linux" else windows_setup_id
    selected_engine = select_engine_resource(config, selected_setup_id, normalized_platform)

    copy_config_without_modification(resolved_config_in, resolved_config_out)

    extra_top_level_excludes = collect_generated_top_level_excludes(
        repo_root=resolved_repo_root,
        generated_paths=[resolved_files_dir, resolved_config_out, resolved_meta_out],
    )
    game_dir = prepare_game_directory(
        repo_root=resolved_repo_root,
        files_dir=resolved_files_dir,
        game_name=game_name,
        git_hash=git_hash,
        extra_top_level_excludes=extra_top_level_excludes,
    )

    meta = PackageAssetsMeta(
        gitHash=git_hash,
        gameName=game_name,
        gameDirectory=game_dir.relative_to(resolved_files_dir).as_posix(),
        engineResource=selected_engine,
        platform=normalized_platform,
    )
    write_json_dict(resolved_meta_out, meta.model_dump(mode="json"), pretty=True)

    write_rapid_alias_metadata(files_dir=resolved_files_dir, git_hash=git_hash, game_name=game_name)

    print(f"Prepared packaged assets for {normalized_platform}")
    print(f"Game: {game_name}")
    print(f"Engine destination: {selected_engine.destination}")
    print("Copied config.json without modification")
    print("Generated rapid alias metadata")


def normalize_platform(platform: str) -> Literal["linux", "win32"]:
    if platform not in {"linux", "win32"}:
        raise RuntimeError(f"Unsupported platform: {platform}")
    return "linux" if platform == "linux" else "win32"


def select_engine_resource(config: DistConfig, setup_id: str, platform: str) -> EngineResource:
    setup = get_setup_by_id(config, setup_id)
    if setup is None:
        raise RuntimeError(f"Setup '{setup_id}' not found in config.json for platform: {platform}")

    resource = get_primary_engine_resource(setup)
    if resource is None:
        raise RuntimeError(f"Setup '{setup_id}' has no usable engine resource entry for platform: {platform}")
    return resource


def get_primary_engine_resource(setup: SetupConfig) -> EngineResource | None:
    if not setup.downloads.resources:
        return None
    resource = setup.downloads.resources[0]
    if resource.url is None or resource.destination is None:
        return None
    return resource


def get_setup_by_id(config: DistConfig, setup_id: str) -> SetupConfig | None:
    for setup in config.setups:
        if setup.package.id == setup_id:
            return setup
    return None


def copy_config_without_modification(config_in: Path, config_out: Path) -> None:
    config_out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(config_in, config_out)


def resolve_game_name_from_modinfo(repo_root: Path, git_hash: str) -> str:
    modinfo_path = repo_root / "modinfo.lua"
    modinfo_text = modinfo_path.read_text(encoding="utf-8")

    name = parse_modinfo_string_field(modinfo_text, "name")
    version = parse_modinfo_string_field(modinfo_text, "version")
    if name is None:
        raise RuntimeError(f"Expected string field 'name' in {modinfo_path}")
    if version is None:
        raise RuntimeError(f"Expected string field 'version' in {modinfo_path}")

    resolved_version = version.replace("$VERSION", git_hash)
    return f"{name} {resolved_version}".strip()


def parse_modinfo_string_field(modinfo_text: str, field_name: str) -> str | None:
    pattern = rf"^\s*{re.escape(field_name)}\s*=\s*[\"']([^\"']+)[\"']"
    match = re.search(pattern, modinfo_text, flags=re.MULTILINE)
    if match is None:
        return None
    return match.group(1)


def prepare_game_directory(
    repo_root: Path,
    files_dir: Path,
    game_name: str,
    git_hash: str,
    extra_top_level_excludes: set[str],
) -> Path:
    game_dir = files_dir / "games" / f"{game_name}.sdd"
    shutil.rmtree(game_dir, ignore_errors=True)
    game_dir.mkdir(parents=True, exist_ok=True)
    copy_repo_filtered(repo_root, game_dir, extra_top_level_excludes)

    modinfo_path = game_dir / "modinfo.lua"
    modinfo_text = modinfo_path.read_text(encoding="utf-8")
    if "$VERSION" not in modinfo_text:
        raise RuntimeError(f"Expected $VERSION placeholder in {modinfo_path}")
    modinfo_path.write_text(modinfo_text.replace("$VERSION", git_hash), encoding="utf-8")
    return game_dir


def main() -> None:
    app()
