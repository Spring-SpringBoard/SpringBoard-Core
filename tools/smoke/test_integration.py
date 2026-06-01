"""In-engine integration tests.

Boots SBC with `SBC_TEST_SPEC` set so the native plugin runs the named
integration tests inside a live engine (mutating Spring via real commands and
verifying via engine queries), then reads back the results file and asserts each
test passed.

This is the layer that proves commands actually work — unlike the baseline smoke
tests, which only prove SBC boots clean.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from run_sbc import boot


@pytest.fixture(scope="session")
def integration_results() -> dict:
    write_dir = boot(
        tests=[
            "terrain_level_brush",
            "terrain_shape_brush",
            "terrain_drag_stroke",
        ]
    )
    results_path = write_dir / "sbc_test_results.json"
    if not results_path.is_file():
        infolog = write_dir / "infolog.txt"
        tail = ""
        if infolog.is_file():
            tail = "\n".join(infolog.read_text(errors="replace").splitlines()[-40:])
        pytest.fail(
            f"no integration results at {results_path} — the in-engine test "
            f"framework didn't run (or the update callin never fired).\n"
            f"infolog tail:\n{tail}"
        )
    return json.loads(results_path.read_text())


def _result(results: dict, name: str) -> dict:
    for r in results.get("results", []):
        if r["name"] == name:
            return r
    raise AssertionError(f"no result for test {name!r} in {results}")


def test_terrain_level_brush(integration_results: dict) -> None:
    r = _result(integration_results, "terrain_level_brush")
    assert r["passed"], f"terrain_level_brush failed: {r['message']}"


def test_terrain_shape_brush(integration_results: dict) -> None:
    r = _result(integration_results, "terrain_shape_brush")
    assert r["passed"], f"terrain_shape_brush failed: {r['message']}"


def test_terrain_drag_stroke(integration_results: dict) -> None:
    r = _result(integration_results, "terrain_drag_stroke")
    assert r["passed"], f"terrain_drag_stroke failed: {r['message']}"
