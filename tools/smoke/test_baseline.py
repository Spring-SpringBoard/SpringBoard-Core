"""Baseline assertions: every SBC commit must satisfy these. Zero tolerance."""

from smoke.log_assertions import contains, find_crashes, find_errors, find_warnings


def test_no_crash_signatures(infolog: str) -> None:
    crashes = find_crashes(infolog)
    assert not crashes, "crash signatures found:\n" + "\n".join(crashes[:20])


def test_no_warnings(infolog: str) -> None:
    warnings = find_warnings(infolog)
    assert not warnings, f"unexpected warnings ({len(warnings)}):\n" + "\n".join(warnings[:20])


def test_no_errors(infolog: str) -> None:
    errors = find_errors(infolog)
    assert not errors, f"errors found ({len(errors)}):\n" + "\n".join(errors[:20])


def test_luaui_loaded(infolog: str) -> None:
    assert contains(infolog, "Loading LuaUI"), "LuaUI did not load"
