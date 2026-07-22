"""Pytest fixtures.

Shared SBC boot: one engine run per pytest session, all tests assert against
that single run's infolog. If we ever need per-test isolation (e.g. testing
specific commands), introduce a function-scoped fixture and let callers opt in.
"""

from pathlib import Path

import pytest

from smoke.engine import boot


@pytest.fixture(scope="session")
def infolog(tmp_path_factory: pytest.TempPathFactory) -> str:
    # Boot through the in-engine test framework with a tag that matches no test:
    # it loads SBC fully, runs zero tests, then quits cleanly (from Rust). That
    # gives a deterministic, fully-flushed infolog of a clean startup -- without
    # letting the game simulation advance (a running sim emits periodic engine
    # warnings like "Sync checking disabled!" that are unrelated to SBC).
    write_dir: Path = boot(tags=["__startup_only__"])
    infolog_path = write_dir / "infolog.txt"
    if not infolog_path.is_file():
        pytest.fail(f"no infolog produced at {infolog_path}")
    return infolog_path.read_text(errors="replace")
