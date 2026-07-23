"""Step-down ordering for Python functions and methods."""

import ast
from collections.abc import Iterable
from pathlib import Path

ROOTS = ("build", "tools/e2e", "tools/lint", "tools/smoke")
EXCLUDE_DIRS = frozenset({".venv", "__pycache__", ".pytest_cache", ".ruff_cache", ".mypy_cache"})
type Function = ast.FunctionDef | ast.AsyncFunctionDef


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
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    errors = _check_scope(path, tree.body, "function")
    for class_def in _classes(tree.body):
        errors.extend(_check_class(path, class_def))
    return errors


def _check_class(path: Path, class_def: ast.ClassDef) -> list[str]:
    errors = _check_scope(path, class_def.body, "method")
    for nested in _classes(class_def.body):
        errors.extend(_check_class(path, nested))
    return errors


def _check_scope(path: Path, body: Iterable[ast.stmt], subject: str) -> list[str]:
    errors: list[str] = []
    first_private: Function | None = None
    for statement in body:
        if not isinstance(statement, ast.FunctionDef | ast.AsyncFunctionDef):
            continue
        if _is_private(statement.name):
            first_private = first_private or statement
        elif first_private is not None:
            private_label = "helper" if subject == "function" else "method"
            errors.append(
                f"{path}:{statement.lineno}: public {subject} `{statement.name}` appears after "
                f"private {private_label} at line {first_private.lineno} (`def {first_private.name}`)"
            )
    return errors


def _classes(body: Iterable[ast.stmt]) -> Iterable[ast.ClassDef]:
    return (statement for statement in body if isinstance(statement, ast.ClassDef))


def _is_private(name: str) -> bool:
    return name.startswith("_") and not name.startswith("__")
