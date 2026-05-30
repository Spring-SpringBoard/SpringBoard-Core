"""Helpers for asserting on a Spring infolog.

Tests in test_*.py call these with the `infolog` fixture (full log text as a string).
"""

import re


CRASH_PATTERNS = (
    r"CrashHandler\b.*Error",
    r"XIO.*fatal",
    r"terminate called without an active exception",
    r"thread .* panicked",
    r"RUST_BACKTRACE",
)
_CRASH_RE = re.compile("|".join(CRASH_PATTERNS))


def find_crashes(infolog: str) -> list[str]:
    return [line for line in infolog.splitlines() if _CRASH_RE.search(line)]


_WARNING_RE = re.compile(r"\bWarning:\s", re.IGNORECASE)


def find_warnings(infolog: str) -> list[str]:
    return [line for line in infolog.splitlines() if _WARNING_RE.search(line)]


_ERROR_RE = re.compile(r"\[ERROR\]|\bError:\s", re.IGNORECASE)


def find_errors(infolog: str) -> list[str]:
    return [line for line in infolog.splitlines() if _ERROR_RE.search(line)]


def contains(infolog: str, needle: str) -> bool:
    return needle in infolog
