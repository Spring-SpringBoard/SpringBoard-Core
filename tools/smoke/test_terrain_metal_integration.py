import pytest

from integration_runner import result, run_named_tests


@pytest.fixture(scope="module")
def integration_results() -> dict:
    return run_named_tests(["terrain_metal_brush"])


def test_terrain_metal_brush(integration_results: dict) -> None:
    r = result(integration_results, "terrain_metal_brush")
    assert r["passed"], f"terrain_metal_brush failed: {r['message']}"
