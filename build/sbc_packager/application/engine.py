import shutil
import subprocess
from pathlib import Path

PRUNED_ENGINE_DIRECTORIES = ("AI",)
PRUNED_ENGINE_EXECUTABLES = ("pr-downloader", "spring-dedicated", "spring-headless")
PRUNED_WINDOWS_IMPORT_LIBRARIES = ("libspring-dedicated.dll.a", "libspring-headless.dll.a")


def install_engine(*, destination: Path, engine_archive: Path) -> None:
    seven_zip = shutil.which("7z")
    if seven_zip is None:
        raise RuntimeError("7z is required to extract the engine archive")
    destination.mkdir(parents=True)
    subprocess.run([seven_zip, "x", "-y", f"-o{destination}", str(engine_archive.resolve())], check=True)


def prune_engine(application_dir: Path, platform: str) -> None:
    executable_suffix = "" if platform == "linux" else ".exe"
    for executable in PRUNED_ENGINE_EXECUTABLES:
        (application_dir / f"{executable}{executable_suffix}").unlink(missing_ok=True)
    if platform == "win32":
        for import_library in PRUNED_WINDOWS_IMPORT_LIBRARIES:
            (application_dir / import_library).unlink(missing_ok=True)
    for directory in PRUNED_ENGINE_DIRECTORIES:
        path = application_dir / directory
        if path.is_symlink() or path.is_file():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)


def rename_engine(application_dir: Path, platform: str) -> Path:
    source = application_dir / ("spring" if platform == "linux" else "spring.exe")
    destination = application_dir / ("SpringBoard" if platform == "linux" else "SpringBoard.exe")
    if not source.is_file():
        raise RuntimeError(f"Engine executable is missing: {source}")
    if destination.exists():
        raise RuntimeError(f"Application executable already exists: {destination}")
    source.rename(destination)
    if platform == "linux" and not destination.stat().st_mode & 0o111:
        raise RuntimeError(f"Engine executable lost its executable mode: {destination}")
    return destination
