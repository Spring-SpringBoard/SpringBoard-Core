#!/usr/bin/env python3
import re
import sys
from pathlib import Path


PUBLIC_FN = re.compile(r"^pub(?:\([^)]*\))?\s+(?:async\s+)?fn\s+([A-Za-z0-9_]+)")
PRIVATE_FN = re.compile(r"^fn\s+([A-Za-z0-9_]+)")


def main() -> int:
    root = Path("native/src/sbc")
    errors: list[str] = []
    for path in sorted(root.rglob("*.rs")):
        errors.extend(check_file(path))
    if errors:
        print("Rust step-down ordering violations:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        return 1
    return 0


def check_file(path: Path) -> list[str]:
    errors: list[str] = []
    first_private: tuple[int, str] | None = None
    for lineno, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if PRIVATE_FN.match(line):
            if first_private is None:
                first_private = (lineno, line.strip())
            continue
        match = PUBLIC_FN.match(line)
        if match and first_private is not None:
            errors.append(
                f"{path}:{lineno}: public function `{match.group(1)}` appears after "
                f"private helper at line {first_private[0]} (`{first_private[1]}`)"
            )
    return errors


if __name__ == "__main__":
    raise SystemExit(main())
