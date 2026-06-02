import pytest

from integration_runner import result, run_named_tests


@pytest.fixture(scope="module")
def integration_results() -> dict:
    return run_named_tests(["terrain_shape_brush"])


def test_terrain_shape_brush(integration_results: dict) -> None:
    r = result(integration_results, "terrain_shape_brush")
    assert r["passed"], f"terrain_shape_brush failed: {r['message']}"
