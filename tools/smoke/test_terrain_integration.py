import pytest

from integration_runner import result, run_named_tests


@pytest.fixture(scope="module")
def integration_results() -> dict:
    return run_named_tests([
        "terrain_level_brush",
        "terrain_shape_brush",
        "terrain_drag_stroke",
    ])


def test_terrain_level_brush(integration_results: dict) -> None:
    r = result(integration_results, "terrain_level_brush")
    assert r["passed"], f"terrain_level_brush failed: {r['message']}"


def test_terrain_shape_brush(integration_results: dict) -> None:
    r = result(integration_results, "terrain_shape_brush")
    assert r["passed"], f"terrain_shape_brush failed: {r['message']}"


def test_terrain_drag_stroke(integration_results: dict) -> None:
    r = result(integration_results, "terrain_drag_stroke")
    assert r["passed"], f"terrain_drag_stroke failed: {r['message']}"
