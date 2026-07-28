"""Fail when a `mod.rs` carries implementation code instead of wiring modules.

A `mod.rs` should declare modules and re-export their items — nothing else. Real
code (functions, and by extension the types/impls around them) belongs in a
named sibling file, so the module tree stays skimmable. Mirrors the shell check
`mod.rs` may define the small types that name its boundary, but implementations
belong in a named sibling file. This keeps the module tree skimmable and makes
the implementation's responsibility explicit.
"""

import re
from pathlib import Path

ROOT = Path("native/src/sbc")
# A function item or inherent/trait implementation anywhere in the file.
FN = re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?fn\s+[A-Za-z0-9_]+")
IMPL = re.compile(r"^\s*impl(?:\s*<[^>]+>)?\s+(?:[^\s]+\s+for\s+)?[^\s{]+")


def check() -> int:
    offenders: list[str] = []
    for path in sorted(ROOT.rglob("mod.rs")):
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if FN.match(line) or IMPL.match(line):
                offenders.append(f"{path}:{lineno}: {line.strip()}")
    if offenders:
        print(
            "mod.rs files must not define functions or impl blocks. Move the implementation to a named sibling file:",
        )
        for offender in offenders:
            print(f"  {offender}")
        return 1
    return 0
