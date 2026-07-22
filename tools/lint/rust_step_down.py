#!/usr/bin/env python3
import re
from dataclasses import dataclass
from pathlib import Path

PUBLIC_FN = re.compile(r"^\s*pub(?:\([^)]*\))?\s+(?:async\s+)?fn\s+([A-Za-z0-9_]+)")
PRIVATE_FN = re.compile(r"^\s*(?:async\s+)?fn\s+([A-Za-z0-9_]+)")
IMPL_START = re.compile(r"^\s*impl(?:\s|<)")


@dataclass
class ImplBlock:
    depth: int
    first_private: tuple[int, str] | None = None


def check() -> int:
    root = Path("native/src/sbc")
    errors: list[str] = []
    for path in sorted(root.rglob("*.rs")):
        errors.extend(check_file(path))
    if errors:
        print("Rust step-down ordering violations:")
        for error in errors:
            print(f"  {error}")
        return 1
    return 0


def check_file(path: Path) -> list[str]:
    errors: list[str] = []
    first_private: tuple[int, str] | None = None
    impls: list[ImplBlock] = []
    pending_impl = False
    brace_depth = 0

    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if IMPL_START.match(line):
            pending_impl = True

        impl = impls[-1] if impls and brace_depth == impls[-1].depth else None
        if impl is not None:
            first = impl.first_private
            if PRIVATE_FN.match(line):
                if first is None:
                    impl.first_private = (lineno, line.strip())
            elif (match := PUBLIC_FN.match(line)) and first is not None:
                first_line, first_text = first
                errors.append(
                    f"{path}:{lineno}: public method `{match.group(1)}` appears after "
                    f"private method at line {first_line} (`{first_text}`)"
                )
        elif brace_depth == 0:
            if PRIVATE_FN.match(line):
                if first_private is None:
                    first_private = (lineno, line.strip())
            elif (match := PUBLIC_FN.match(line)) and first_private is not None:
                errors.append(
                    f"{path}:{lineno}: public function `{match.group(1)}` appears after "
                    f"private helper at line {first_private[0]} (`{first_private[1]}`)"
                )

        opens = line.count("{")
        closes = line.count("}")
        if pending_impl and opens:
            impls.append(ImplBlock(depth=brace_depth + 1))
            pending_impl = False
        brace_depth += opens - closes
        while impls and brace_depth < impls[-1].depth:
            impls.pop()
    return errors
