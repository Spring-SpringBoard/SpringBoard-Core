#!/usr/bin/env python3
"""Fail when a `mod.rs` carries code instead of only wiring submodules.

A `mod.rs` should declare modules and re-export their items — nothing else. Real
code (functions, and by extension the types/impls around them) belongs in a
named sibling file, so the module tree stays skimmable. Mirrors the shell check
`fd mod.rs -x grep -ln fn`, but as a gate with a clear message.
"""

import re
from pathlib import Path

ROOT = Path("native/src/sbc")
# A function item anywhere in the file, public or private, incl. `async`.
FN = re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?fn\s+[A-Za-z0-9_]+")


def check() -> int:
    offenders: list[str] = []
    for path in sorted(ROOT.rglob("mod.rs")):
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if FN.match(line):
                offenders.append(f"{path}:{lineno}: {line.strip()}")
    if offenders:
        print(
            "mod.rs files must only declare and re-export modules, not define "
            "functions. Move the code to a named sibling file:",
        )
        for offender in offenders:
            print(f"  {offender}")
        return 1
    return 0
