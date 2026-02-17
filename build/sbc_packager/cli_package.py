from __future__ import annotations

from pathlib import Path
from typing import Annotated

import typer

from .cli_download_engine import download_engine
from .cli_make_package_json import make_package_json
from .cli_prepare import prepare_packaged_assets

app = typer.Typer(add_completion=False, no_args_is_help=True)


@app.command(name="package")
def package_command(
    repo_root: Annotated[Path, typer.Option(..., "--repo-root", exists=True, file_okay=False)],
    config_in: Annotated[Path, typer.Option(..., "--config-in", exists=True, dir_okay=False)],
    config_out: Annotated[Path, typer.Option(..., "--config-out")],
    files_dir: Annotated[Path, typer.Option(..., "--files-dir")],
    meta_out: Annotated[Path, typer.Option(..., "--meta-out")],
    package_json: Annotated[Path, typer.Option(..., "--package-json")],
    repo_full_name: Annotated[str, typer.Option(..., "--repo-full-name")],
    platform: Annotated[str, typer.Option(..., "--platform")],
    git_hash: Annotated[str, typer.Option(..., "--git-hash")],
    package_version: Annotated[str, typer.Option(..., "--package-version")],
    linux_setup_id: Annotated[str, typer.Option("--linux-setup-id")] = "latest-linux",
    windows_setup_id: Annotated[str, typer.Option("--windows-setup-id")] = "latest-win",
) -> None:
    run_packaging_pipeline(
        repo_root=repo_root,
        config_in=config_in,
        config_out=config_out,
        files_dir=files_dir,
        meta_out=meta_out,
        package_json=package_json,
        repo_full_name=repo_full_name,
        platform=platform,
        git_hash=git_hash,
        package_version=package_version,
        linux_setup_id=linux_setup_id,
        windows_setup_id=windows_setup_id,
    )
    print(f"Pipeline finished with git hash: {git_hash}")
    print(f"Pipeline finished with package version: {package_version}")


def run_packaging_pipeline(
    repo_root: Path,
    config_in: Path,
    config_out: Path,
    files_dir: Path,
    meta_out: Path,
    package_json: Path,
    repo_full_name: str,
    platform: str,
    git_hash: str,
    package_version: str,
    linux_setup_id: str,
    windows_setup_id: str,
) -> None:
    resolved_repo_root = repo_root.resolve()
    resolved_config_in = config_in.resolve()
    resolved_config_out = config_out.resolve()
    resolved_files_dir = files_dir.resolve()
    resolved_meta_out = meta_out.resolve()
    resolved_package_json = package_json.resolve()

    if not resolved_package_json.is_file():
        raise RuntimeError(
            "Missing launcher package.json at "
            f"{resolved_package_json}. "
            "Initialize a launcher build tree first (copy spring-launcher files into the build directory), "
            "then rerun sbc-packager-package."
        )

    prepare_packaged_assets(
        repo_root=resolved_repo_root,
        config_in=resolved_config_in,
        config_out=resolved_config_out,
        files_dir=resolved_files_dir,
        meta_out=resolved_meta_out,
        git_hash=git_hash,
        platform=platform,
        linux_setup_id=linux_setup_id,
        windows_setup_id=windows_setup_id,
    )

    download_engine(meta_file=resolved_meta_out, files_dir=resolved_files_dir)

    make_package_json(
        package_json=resolved_package_json,
        config_json=resolved_config_out,
        repo_full_name=repo_full_name,
        version=package_version,
    )


def main() -> None:
    app()
