import re
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIRS = (
    ROOT / "scen_edit",
    ROOT / "native" / "src",
    ROOT / "tools" / "smoke",
)
SOURCE_SUFFIXES = {".lua", ".rs", ".py"}


@dataclass
class CommandInfo:
    name: str
    lua_defs: list[Path] = field(default_factory=list)
    rust_defs: list[Path] = field(default_factory=list)
    uses: list[tuple[Path, int, str]] = field(default_factory=list)


def check(*, show_all: bool = False, fail: bool = False) -> int:
    files = source_files()
    commands = collect_definitions(files)
    collect_uses(files, commands)

    unused = [command for command in commands.values() if not command.uses]
    to_print = sorted(commands.values() if show_all else unused, key=lambda c: c.name)

    for command in to_print:
        sides = []
        if command.lua_defs:
            sides.append("lua=" + ",".join(rel(path) for path in command.lua_defs))
        if command.rust_defs:
            sides.append("rust=" + ",".join(rel(path) for path in command.rust_defs))
        use_text = "unused" if not command.uses else f"{len(command.uses)} use(s)"
        print(f"{command.name}: {use_text}; " + "; ".join(sides))
        if show_all:
            for path, line, kind in command.uses[:5]:
                print(f"  {kind}: {rel(path)}:{line}")
            if len(command.uses) > 5:
                print(f"  ... {len(command.uses) - 5} more")

    if unused:
        print(f"\n{len(unused)} command(s) have no instantiation evidence.")
    return 1 if fail and unused else 0


def source_files() -> list[Path]:
    files: list[Path] = []
    for source_dir in SOURCE_DIRS:
        if not source_dir.exists():
            continue
        for path in source_dir.rglob("*"):
            if path.is_file() and path.suffix in SOURCE_SUFFIXES:
                files.append(path)
    return files


def collect_definitions(files: list[Path]) -> dict[str, CommandInfo]:
    commands: dict[str, CommandInfo] = {}
    lua_class_name = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\.className\s*=\s*[\"']([A-Za-z_][A-Za-z0-9_]*)[\"']")
    rust_registration = re.compile(
        r"register_command!\s*\([^,]+,\s*[\"']([A-Za-z_][A-Za-z0-9_]*)[\"']",
        re.S,
    )

    for path in files:
        text = path.read_text(errors="ignore")
        if path.suffix == ".lua":
            for match in lua_class_name.finditer(text):
                name = match.group(1)
                commands.setdefault(name, CommandInfo(name)).lua_defs.append(path)
        elif path.suffix == ".rs":
            for match in rust_registration.finditer(text):
                name = match.group(1)
                commands.setdefault(name, CommandInfo(name)).rust_defs.append(path)
    return commands


def collect_uses(files: list[Path], commands: dict[str, CommandInfo]) -> None:
    if not commands:
        return

    command_alt = "|".join(re.escape(name) for name in sorted(commands, key=len, reverse=True))
    # Lua constructs commands as `CommandName(...)`; Rust conventionally uses
    # the associated constructor, `CommandName::new(...)`.
    constructor = re.compile(rf"\b({command_alt})(?:\s*\(|\s*::\s*new\s*\()")
    lua_class_name = re.compile(rf"\b[A-Za-z_][A-Za-z0-9_]*\.className\s*=\s*[\"']({command_alt})[\"']")
    rust_registration = re.compile(
        rf"register_command!\s*\([^,]+,\s*[\"']({command_alt})[\"']",
        re.S,
    )
    json_class_name = re.compile(rf"[\"']className[\"']\s*[:=]\s*[\"']({command_alt})[\"']")
    lua_extends = re.compile(rf"\b({command_alt})\s*:\s*extends\b")
    # Catches dynamic dispatch fed by string payloads (`env[className]()`).
    string_ref = re.compile(rf"[\"']({command_alt})[\"']")

    patterns = (
        ("constructor", constructor),
        ("json-className", json_class_name),
        ("lua-class", lua_class_name),
        ("rust-register", rust_registration),
        ("lua-extends", lua_extends),
        ("string-ref", string_ref),
    )
    for path in files:
        text = path.read_text(errors="ignore")
        lines = text.splitlines()
        for kind, pattern in patterns:
            for match in pattern.finditer(text):
                name = match.group(1)
                line = line_number(text, match.start())
                if kind == "string-ref":
                    # A class's own def/registration line is not a use.
                    line_text = lines[line - 1] if line - 1 < len(lines) else ""
                    if "className" in line_text or "register_command!" in line_text:
                        continue
                command = commands[name]
                if is_definition_hit(command, path, line, kind):
                    continue
                command.uses.append((path, line, kind))


def is_definition_hit(command: CommandInfo, path: Path, line: int, kind: str) -> bool:
    if kind == "lua-class" and path in command.lua_defs:
        return True
    return kind == "rust-register" and path in command.rust_defs


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT))


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1
