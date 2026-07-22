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
            impl.first_private = _check_scope(path, lineno, line, impl.first_private, "method", errors)
        elif brace_depth == 0:
            first_private = _check_scope(path, lineno, line, first_private, "function", errors)

        opens = line.count("{")
        closes = line.count("}")
        if pending_impl and opens:
            impls.append(ImplBlock(depth=brace_depth + 1))
            pending_impl = False
        brace_depth += opens - closes
        while impls and brace_depth < impls[-1].depth:
            impls.pop()
    return errors


def _check_scope(
    path: Path,
    lineno: int,
    line: str,
    first_private: tuple[int, str] | None,
    subject: str,
    errors: list[str],
) -> tuple[int, str] | None:
    if PRIVATE_FN.match(line):
        return first_private or (lineno, line.strip())
    match = PUBLIC_FN.match(line)
    if match is not None and first_private is not None:
        first_line, first_text = first_private
        private_label = "helper" if subject == "function" else "method"
        errors.append(
            f"{path}:{lineno}: public {subject} `{match.group(1)}` appears after "
            f"private {private_label} at line {first_line} (`{first_text}`)"
        )
    return first_private
