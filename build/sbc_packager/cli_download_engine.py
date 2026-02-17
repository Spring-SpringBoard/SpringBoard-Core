from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Annotated

import typer

from .json_io import read_json_dict
from .models import PackageAssetsMeta

app = typer.Typer(add_completion=False, no_args_is_help=True)


@app.command(name="download-engine")
def download_engine_command(
    meta: Annotated[Path, typer.Option(..., "--meta", exists=True, dir_okay=False)],
    files_dir: Annotated[Path, typer.Option(..., "--files-dir")],
) -> None:
    download_engine(meta_file=meta, files_dir=files_dir)


def download_engine(meta_file: Path, files_dir: Path) -> None:
    meta = PackageAssetsMeta.model_validate(read_json_dict(meta_file.resolve()))
    engine_resource = meta.engineResource

    if engine_resource.url is None or engine_resource.destination is None:
        raise RuntimeError(f"Invalid metadata: missing engine resource fields in {meta_file}")

    destination_path = (files_dir.resolve() / engine_resource.destination).resolve()
    if directory_has_content(destination_path):
        print(f"Skipping engine extraction, destination already exists: {destination_path}")
        return

    destination_path.mkdir(parents=True, exist_ok=True)
    archive_path = download_with_retries(engine_resource.url)

    try:
        print(f"Extracting engine to: {destination_path}")
        subprocess.run(
            ["7z", "x", "-y", str(archive_path), f"-o{destination_path}"],
            check=True,
        )
    finally:
        archive_path.unlink(missing_ok=True)

    print("Engine extraction finished")


def directory_has_content(path: Path) -> bool:
    if not path.is_dir():
        return False
    return any(path.iterdir())


def download_with_retries(url: str, max_attempts: int = 4) -> Path:
    archive_fd, archive_path_str = tempfile.mkstemp(prefix="sbc-engine-", suffix=".7z")
    archive_path = Path(archive_path_str)
    os.close(archive_fd)

    for attempt in range(1, max_attempts + 1):
        try:
            print(f"Downloading engine: {url}")
            with urllib.request.urlopen(url, timeout=60) as response, archive_path.open("wb") as output_file:
                shutil.copyfileobj(response, output_file)
            return archive_path
        except (urllib.error.URLError, TimeoutError) as error:
            if attempt == max_attempts:
                raise RuntimeError(f"Failed to download engine after {max_attempts} attempts") from error
            print(f"Download attempt {attempt}/{max_attempts} failed: {error}")
            time.sleep(attempt)

    raise RuntimeError("Unreachable code: retries exhausted")


def main() -> None:
    app()
