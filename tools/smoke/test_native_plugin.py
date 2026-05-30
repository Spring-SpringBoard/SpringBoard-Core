"""Assertions specific to the Rust native plugin."""

from log_assertions import contains
from run_sbc import SBC_ROOT


def test_engine_loaded_expected_plugin(infolog: str) -> None:
    expected = SBC_ROOT / "native" / "target" / "release" / "librust_plugin.so"
    needle = f"Successfully opened plugin {expected}"
    assert contains(infolog, needle), (
        f"engine did not load the expected native plugin\n  expected: {needle}"
    )


def test_plugin_init_log_fired(infolog: str) -> None:
    # The slim scaffolding plugin emits this exact line via log4rs on init.
    assert contains(infolog, "SBC logging enabled"), (
        "native plugin did not initialize (no 'SBC logging enabled' line)"
    )
