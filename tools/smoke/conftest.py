"""Pytest fixtures.

Shared SBC boot: one engine run per pytest session, all tests assert against
that single run's infolog. If we ever need per-test isolation (e.g. testing
specific commands), introduce a function-scoped fixture and let callers opt in.
"""

import pytest
from pathlib import Path

from run_sbc import boot


@pytest.fixture(scope="session")
def infolog(tmp_path_factory: pytest.TempPathFactory) -> str:
    write_dir: Path = boot()
    infolog_path = write_dir / "infolog.txt"
    if not infolog_path.is_file():
        pytest.fail(f"no infolog produced at {infolog_path}")
    return infolog_path.read_text(errors="replace")
