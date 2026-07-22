import gzip
import hashlib
import shutil
from pathlib import Path


def create_application_archive(application_dir: Path, platform: str) -> Path:
    archive_format = "gztar" if platform == "linux" else "zip"
    suffix = ".tar.gz" if platform == "linux" else ".zip"
    expected = application_dir.with_name(application_dir.name + suffix)
    if expected.exists():
        raise RuntimeError(f"Refusing to overwrite existing application archive: {expected}")
    return Path(
        shutil.make_archive(
            str(application_dir),
            archive_format,
            root_dir=application_dir.parent,
            base_dir=application_dir.name,
        )
    )


def write_file_manifest(application_dir: Path) -> Path:
    manifest_path = application_dir / "files.md5.gz"
    entries: list[str] = []
    for path in sorted(application_dir.rglob("*")):
        if path == manifest_path or path.is_symlink() or not path.is_file() or path.suffix == ".dbg":
            continue
        relative = path.relative_to(application_dir).as_posix()
        entries.append(f"{file_md5(path)}  ./{relative}\n")
    with (
        manifest_path.open("wb") as output,
        gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as compressed,
    ):
        compressed.write("".join(entries).encode())
    return manifest_path


def file_md5(path: Path) -> str:
    digest = hashlib.md5(usedforsecurity=False)
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()
