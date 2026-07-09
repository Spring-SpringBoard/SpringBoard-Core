from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Case:
    name: str
    flags: dict[str, str]
    scenario: str
    crop: str | None = None


def target_cases(target: str, case: str) -> list[Case]:
    if target == "chonsole":
        cases = [
            Case(
                name="chonsole-lua-baseline",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="chonsole_editing",
            ),
            Case(
                name="chonsole-rust-port",
                flags={"chonsole": "rust", "env_panel": "lua", "ui": "chili"},
                scenario="chonsole_editing",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:]
        return cases
    if target == "main-panel":
        cases = [
            Case(
                name="main-panel-lua-chili",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="main_panel_tabs",
                crop="right-panel",
            ),
            Case(
                name="main-panel-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="main_panel_tabs",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:]
        return cases
    if target == "lighting-panel":
        cases = [
            Case(
                name="lighting-panel-lua-chili",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="lighting_panel",
                crop="right-panel",
            ),
            Case(
                name="lighting-panel-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="lighting_panel",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:]
        return cases
    if target == "units-panel":
        cases = [
            Case(
                name="units-panel-lua-chili",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="units_panel",
                crop="right-panel",
            ),
            Case(
                name="units-panel-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="units_panel",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:]
        return cases
    if target == "teams-panel":
        cases = [
            Case(
                name="teams-panel-lua-chili",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="teams_panel",
                crop="right-panel",
            ),
            Case(
                name="teams-panel-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="teams_panel",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:]
        return cases
    if target == "info-panel":
        cases = [
            Case(
                name="info-panel-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="info_panel",
                crop="right-panel",
            ),
        ]
        return cases
    if target == "props-panel":
        return [
            Case(
                name="props-panel-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="props_panel",
                crop="right-panel",
            ),
        ]
    if target == "notifications":
        cases = [
            Case(
                name="notifications-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="notifications",
            ),
            Case(
                name="notifications-lua-chili",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="notifications",
            ),
        ]
        if case == "lua":
            return cases[1:]
        if case == "rust":
            return cases[:1]
        return cases
    if target == "heightmap":
        cases = [
            Case(
                name="heightmap-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="heightmap",
            ),
            Case(
                name="heightmap-lua-chili",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="heightmap",
            ),
        ]
        if case == "lua":
            return cases[1:]
        if case == "rust":
            return cases[:1]
        return cases
    if target == "all-editors":
        return [
            Case(
                name="all-editors-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="all_editors",
                crop="right-panel",
            ),
        ]
    if target == "dialogs":
        return [
            Case(
                name="dialogs-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="dialogs",
            ),
        ]
    if target == "cursortip":
        return [
            Case(
                name="cursortip-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="cursortip",
            ),
        ]
    if target == "settings-panel":
        return [
            Case(
                name="settings-panel-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="settings_panel",
            ),
        ]
    if target == "dev-console":
        cases = [
            Case(
                name="dev-console-lua-chili",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="dev_console",
            ),
            Case(
                name="dev-console-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="dev_console",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:]
        return cases
    if target == "texture-panel":
        cases = [
            Case(
                name="texture-panel-lua-chili",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "chili"},
                scenario="texture_panel",
                crop="right-panel",
            ),
            Case(
                name="texture-panel-lua-rmlui",
                flags={"chonsole": "lua", "env_panel": "lua", "ui": "rmlui"},
                scenario="texture_panel",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:]
        return cases
    raise ValueError(f"unknown target: {target}")
