"""Helpers for slice-local in-engine integration pytest files."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from run_sbc import boot


def run_named_tests(tests: list[str]) -> dict:
    write_dir = boot(tests=tests)
    results_path = write_dir / "sbc_test_results.json"
    if not results_path.is_file():
        pytest.fail(_missing_results_message(results_path, write_dir / "infolog.txt"))
    return json.loads(results_path.read_text())


def result(results: dict, name: str) -> dict:
    for r in results.get("results", []):
        if r["name"] == name:
            return r
    raise AssertionError(f"no result for test {name!r} in {results}")


def _missing_results_message(results_path: Path, infolog: Path) -> str:
    tail = ""
    if infolog.is_file():
        tail = "\n".join(infolog.read_text(errors="replace").splitlines()[-40:])
    return (
        f"no integration results at {results_path} -- the in-engine test "
        f"framework didn't run (or the update callin never fired).\n"
        f"infolog tail:\n{tail}"
    )
