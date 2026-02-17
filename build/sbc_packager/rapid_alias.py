from __future__ import annotations

import gzip
import hashlib
from pathlib import Path


def write_rapid_alias_metadata(files_dir: Path, git_hash: str, game_name: str) -> None:
    rapid_root = files_dir / "rapid" / "repos.springrts.com"
    sbc_root = rapid_root / "sbc"
    package_hash = hashlib.md5(f"{game_name}|{git_hash}".encode()).hexdigest()

    write_gzip_text(rapid_root / "repos.gz", "sbc,https://repos.springrts.com/sbc,,\n")
    write_gzip_text(
        sbc_root / "versions.gz",
        (
            f"sbc:git:{git_hash},{package_hash},,{game_name}\n"
            f"sbc:test,{package_hash},,{game_name}\n"
        ),
    )


def write_gzip_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wb") as compressed_file:
        compressed_file.write(text.encode("utf-8"))
