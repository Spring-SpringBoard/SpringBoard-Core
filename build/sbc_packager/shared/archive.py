from __future__ import annotations

import hashlib
import shutil
import zipfile
from pathlib import Path

ARCHIVE_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
REGULAR_FILE_MODE = 0o100644


def write_game_archive(source: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob("*"), key=lambda candidate: candidate.as_posix()):
            if not path.is_file():
                continue
            entry = zipfile.ZipInfo(path.relative_to(source).as_posix(), ARCHIVE_TIMESTAMP)
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = REGULAR_FILE_MODE << 16
            with path.open("rb") as input_file, archive.open(entry, "w") as output_file:
                shutil.copyfileobj(input_file, output_file)


def write_sha256(path: Path) -> Path:
    digest = hashlib.sha256()
    with path.open("rb") as artifact:
        for block in iter(lambda: artifact.read(1024 * 1024), b""):
            digest.update(block)
    checksum = path.with_suffix(path.suffix + ".sha256")
    checksum.write_text(f"{digest.hexdigest()}  {path.name}\n", encoding="utf-8")
    return checksum
