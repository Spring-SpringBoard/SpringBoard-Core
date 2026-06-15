"""Helpers for slice-local in-engine integration pytest files."""

from __future__ import annotations

import json
from pathlib import Path
from typing import NamedTuple

import pytest

from run_sbc import boot


class RunOutput(NamedTuple):
    """Everything a slice's pytest file needs about an in-engine boot."""

    results: dict
    infolog: str
    write_dir: Path


def run_tests(tags: list[str] | None = None) -> RunOutput:
    """Boot once, run the registered tests, return results + infolog + write_dir.

    With no `tags`, every test registered via `integration_test!` runs -- the
    Rust registry is the single source of truth, so there is no list to keep in
    sync here. Pass `tags` (substrings of a test's module path) to run only
    those slices (a test runs if its tag contains any of them).

    The infolog is exposed so callers can run the baseline assertions
    (no-warnings / no-errors / no-crashes) against the same boot the tests
    fired into -- otherwise the only infolog under scrutiny is the baseline
    test_no_warnings boot, which doesn't see anything paint commands log.
    """
    write_dir = boot(run_tests=True, tags=tags)
    results_path = write_dir / "sbc_test_results.json"
    infolog_path = write_dir / "infolog.txt"
    infolog = infolog_path.read_text(errors="replace") if infolog_path.is_file() else ""
    if not results_path.is_file():
        pytest.fail(_missing_results_message(results_path, infolog_path))
    return RunOutput(
        results=json.loads(results_path.read_text()),
        infolog=infolog,
        write_dir=write_dir,
    )


def assert_clean_infolog(infolog: str, *, context: str) -> None:
    """Enforce zero errors / warnings / crashes in the run's infolog.

    Bare minimum quality bar (see conventions.md "Rules -- what tests
    assert"): "Zero errors and zero warnings, always. No allowlists." If
    something fires, fix it at the source -- never suppress.

    `context` is included in the failure message so regressions point at
    the right slice's boot.
    """
    from log_assertions import find_crashes, find_errors, find_warnings

    crashes = find_crashes(infolog)
    assert not crashes, f"[{context}] crash signatures:\n" + "\n".join(crashes[:20])

    warnings = find_warnings(infolog)
    assert not warnings, (
        f"[{context}] unexpected warnings ({len(warnings)}):\n"
        + "\n".join(warnings[:40])
    )

    errors = find_errors(infolog)
    assert not errors, (
        f"[{context}] errors ({len(errors)}):\n" + "\n".join(errors[:40])
    )


def _missing_results_message(results_path: Path, infolog: Path) -> str:
    tail = ""
    if infolog.is_file():
        tail = "\n".join(infolog.read_text(errors="replace").splitlines()[-40:])
    return (
        f"no integration results at {results_path} -- the in-engine test "
        f"framework didn't run (or the update callin never fired).\n"
        f"infolog tail:\n{tail}"
    )
