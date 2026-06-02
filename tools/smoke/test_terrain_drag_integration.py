import pytest

from integration_runner import result, run_named_tests


@pytest.fixture(scope="module")
def integration_results() -> dict:
    return run_named_tests(["terrain_drag_stroke"])


def test_terrain_drag_stroke(integration_results: dict) -> None:
    r = result(integration_results, "terrain_drag_stroke")
    assert r["passed"], f"terrain_drag_stroke failed: {r['message']}"
