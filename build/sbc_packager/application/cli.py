from __future__ import annotations

import shutil
from pathlib import Path
from typing import Annotated

import typer

from ..editor.archive import find_engine_loading_image, normalize_platform, prepare_game_archive, resolve_game_name
from ..shared.archive import write_sha256
from ..shared.files import collect_generated_top_level_excludes
from .archive import create_application_archive, write_file_manifest
from .config import read_application_config, render_start_script, write_springsettings
from .engine import install_engine, prune_engine, rename_engine

app = typer.Typer(add_completion=False, no_args_is_help=True)


@app.command(name="application")
def application_command(
    repo_root: Annotated[Path, typer.Option(..., "--repo-root", exists=True, file_okay=False)],
    distribution: Annotated[Path, typer.Option(..., "--distribution", exists=True, dir_okay=False)],
    output_dir: Annotated[Path, typer.Option(..., "--output-dir")],
    native_plugin: Annotated[Path, typer.Option(..., "--native-plugin", exists=True, dir_okay=False)],
    platform: Annotated[str, typer.Option(..., "--platform")],
    version: Annotated[str, typer.Option(..., "--version")],
    engine_archive: Annotated[Path, typer.Option(..., "--engine-archive", exists=True, dir_okay=False)],
    run_config: Annotated[Path, typer.Option("--run-config")] = Path("config/ui-rust.json"),
    editor_archive_output: Annotated[Path | None, typer.Option("--editor-archive-output")] = None,
    archive: Annotated[bool, typer.Option("--archive/--no-archive")] = True,
) -> None:
    build_application(
        repo_root=repo_root,
        distribution=distribution,
        output_dir=output_dir,
        native_plugin=native_plugin,
        engine_archive=engine_archive,
        platform=platform,
        version=version,
        run_config=run_config,
        editor_archive_output=editor_archive_output,
        archive=archive,
    )


def build_application(
    *,
    repo_root: Path,
    distribution: Path,
    output_dir: Path,
    native_plugin: Path,
    engine_archive: Path,
    platform: str,
    version: str,
    run_config: Path,
    editor_archive_output: Path | None,
    archive: bool,
) -> Path:
    normalized_platform = normalize_platform(platform)
    resolved_output = output_dir.resolve()
    if resolved_output.exists():
        raise RuntimeError(f"Refusing to overwrite existing application directory: {resolved_output}")

    install_engine(destination=resolved_output, engine_archive=engine_archive)
    prune_engine(resolved_output, normalized_platform)
    rename_engine(resolved_output, normalized_platform)

    resolved_repo_root = repo_root.resolve()
    game_name = resolve_game_name(resolved_repo_root, version)
    game_archive = prepare_game_archive(
        repo_root=resolved_repo_root,
        files_dir=resolved_output,
        game_name=game_name,
        version=version,
        extra_top_level_excludes=collect_generated_top_level_excludes(resolved_repo_root, [resolved_output]),
        native_plugin=native_plugin,
        platform=normalized_platform,
        run_config=run_config,
        loading_image=find_engine_loading_image(resolved_output),
    )
    if editor_archive_output is not None:
        export_editor_archive(game_archive, editor_archive_output)

    config = read_application_config(distribution.resolve())
    (resolved_output / "script.txt").write_text(render_start_script(game_name, config.launch), encoding="utf-8")
    write_springsettings(config.springsettings, resolved_output)
    write_file_manifest(resolved_output)

    if archive:
        archive_path = create_application_archive(resolved_output, normalized_platform)
        write_sha256(archive_path)
        print(f"Created archive: {archive_path}")
    print(f"Created application: {resolved_output}")
    return resolved_output


def export_editor_archive(game_archive: Path, output: Path) -> Path:
    resolved_output = output.resolve()
    if resolved_output.suffix.lower() != ".sdz":
        raise RuntimeError(f"Editor archive output must end in .sdz: {resolved_output}")
    if resolved_output.exists():
        raise RuntimeError(f"Refusing to overwrite editor archive: {resolved_output}")
    resolved_output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(game_archive, resolved_output)
    write_sha256(resolved_output)
    print(f"Created editor archive: {resolved_output}")
    return resolved_output


def main() -> None:
    app()
