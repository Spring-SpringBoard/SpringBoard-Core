from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def read_json_dict(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as input_file:
        data = json.load(input_file)
    if not isinstance(data, dict):
        raise RuntimeError(f"JSON root must be an object: {path}")
    return data


def write_json_dict(path: Path, data: dict[str, Any], pretty: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as output_file:
        if pretty:
            json.dump(data, output_file, indent=2)
            output_file.write("\n")
            return
        json.dump(data, output_file, separators=(",", ":"))
