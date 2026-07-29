"""In-engine integration smoke: run every registered Rust test in one boot.

The Rust registry (`integration_test!`) is the single source of truth -- no test
names or slices are enumerated here. To run only some slices, set SBC_TEST_TAGS
to a comma-separated list of tag substrings (e.g.
`SBC_TEST_TAGS=textures,texture_command_stroke_undo_redo`).
"""

import os

import pytest

from smoke.integration_runner import RunOutput, assert_clean_infolog, run_tests


@pytest.fixture(scope="module")
def integration_run() -> RunOutput:
    return run_tests(_tags())


def test_all_tests_passed(integration_run: RunOutput) -> None:
    results = integration_run.results["results"]
    assert results, "no integration tests ran"
    failed = [f"{r['name']}: {r['message']}" for r in results if not r.get("passed", False)]
    assert not failed, "Rust integration tests failed:\n" + "\n".join(failed)


def test_infolog_clean(integration_run: RunOutput) -> None:
    assert_clean_infolog(integration_run.infolog, context="integration")


def _tags() -> list[str] | None:
    raw = os.environ.get("SBC_TEST_TAGS", "")
    return [t.strip() for t in raw.split(",") if t.strip()] or None
