import shutil
import tempfile
from pathlib import Path
from typing import Annotated

import typer

from ..shared.archive import write_sha256
from ..shared.files import collect_generated_top_level_excludes
from .archive import normalize_platform, prepare_game_archive, resolve_game_name

app = typer.Typer(add_completion=False, no_args_is_help=True)


@app.command(name="base")
def base_command(
    repo_root: Annotated[Path, typer.Option(..., "--repo-root", exists=True, file_okay=False)],
    native_plugin: Annotated[Path, typer.Option(..., "--native-plugin", exists=True, dir_okay=False)],
    output: Annotated[Path, typer.Option(..., "--output")],
    platform: Annotated[str, typer.Option(..., "--platform")],
    version: Annotated[str, typer.Option(..., "--version")],
    run_config: Annotated[Path, typer.Option("--run-config")] = Path("config/ui-rust.json"),
) -> None:
    build_base_archive(
        repo_root=repo_root,
        native_plugin=native_plugin,
        output=output,
        platform=platform,
        version=version,
        run_config=run_config,
    )


def build_base_archive(
    *,
    repo_root: Path,
    native_plugin: Path,
    output: Path,
    platform: str,
    version: str,
    run_config: Path,
) -> Path:
    normalized_platform = normalize_platform(platform)
    resolved_repo_root = repo_root.resolve()
    resolved_output = output.resolve()
    if resolved_output.suffix.lower() != ".sdz":
        raise RuntimeError(f"Base archive output must end in .sdz: {resolved_output}")
    if resolved_output.exists():
        raise RuntimeError(f"Refusing to overwrite base archive: {resolved_output}")

    resolved_output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="springboard-base-") as staging_directory:
        game_archive = prepare_game_archive(
            repo_root=resolved_repo_root,
            files_dir=Path(staging_directory),
            game_name=resolve_game_name(resolved_repo_root, version),
            version=version,
            extra_top_level_excludes=collect_generated_top_level_excludes(resolved_repo_root, [resolved_output]),
            native_plugin=native_plugin,
            platform=normalized_platform,
            run_config=run_config,
        )
        shutil.move(game_archive, resolved_output)

    write_sha256(resolved_output)
    print(f"Created base archive: {resolved_output}")
    return resolved_output


def main() -> None:
    app()
