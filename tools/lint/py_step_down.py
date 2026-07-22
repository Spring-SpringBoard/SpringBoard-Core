"""Step-down ordering for Python: public functions before private (`_`) helpers.

The Python analogue of tools/lint/rust_step_down.py. A module-level `def name`
is public; `def _name` is a private helper. Public functions must come before
private ones so a file reads top-down from high to low level.
"""

import re
from pathlib import Path

PUBLIC_DEF = re.compile(r"^def ([A-Za-z][A-Za-z0-9_]*)")
PRIVATE_DEF = re.compile(r"^def (_[A-Za-z0-9_]*)")
ROOTS = ("build", "tools/e2e", "tools/lint", "tools/smoke")
EXCLUDE_DIRS = frozenset({".venv", "__pycache__", ".pytest_cache", ".ruff_cache", ".mypy_cache"})


def check() -> int:
    errors: list[str] = []
    for root in ROOTS:
        root_path = Path(root)
        if not root_path.exists():
            continue
        for path in sorted(root_path.rglob("*.py")):
            if EXCLUDE_DIRS.intersection(path.parts):
                continue
            errors.extend(check_file(path))
    if errors:
        print("Python step-down ordering violations:")
        for error in errors:
            print(f"  {error}")
        return 1
    return 0


def check_file(path: Path) -> list[str]:
    errors: list[str] = []
    first_private: tuple[int, str] | None = None
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if PRIVATE_DEF.match(line):
            if first_private is None:
                first_private = (lineno, line.strip())
            continue
        match = PUBLIC_DEF.match(line)
        if match and first_private is not None:
            errors.append(
                f"{path}:{lineno}: public function `{match.group(1)}` appears after "
                f"private helper at line {first_private[0]} (`{first_private[1]}`)"
            )
    return errors
