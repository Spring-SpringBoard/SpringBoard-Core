from __future__ import annotations

from dataclasses import dataclass, replace

TARGETS = (
    "chonsole",
    "main-panel",
    "lighting-panel",
    "sky-panel",
    "water-panel",
    "units-panel",
    "texture-panel",
    "dev-console",
    "teams-panel",
    "info-panel",
    "settings-panel",
    "props-panel",
    "collision",
    "selection",
    "cursortip",
    "notifications",
    "dialogs",
    "all-editors",
    "heightmap",
    "map-editors",
    "native-panel",
    "native-dev-console",
)


@dataclass(frozen=True)
class Case:
    name: str
    flags: dict[str, str]
    scenario: str
    crop: str | None = None
    tags: frozenset[str] = frozenset()


def _tags_for(target: str, case: Case) -> frozenset[str]:
    """Tags are derived from the case, so a new case is selectable without
    remembering to tag it: `target:<name>`, `ui:<impl>`, `chonsole:<impl>`."""
    tags = {f"target:{target}"}
    for key in ("ui", "chonsole"):
        if key in case.flags:
            tags.add(f"{key}:{case.flags[key]}")
    return frozenset(tags)


def select_cases(targets: list[str], tags: list[str]) -> list[Case]:
    """Cases matching every requested tag, across the requested targets.

    `select_cases(["all"], ["ui:rust"])` runs only the native UI.
    """
    chosen = TARGETS if not targets or targets == ["all"] else targets
    wanted = set(tags)
    out: list[Case] = []
    for target in chosen:
        for case in target_cases(target, "all"):
            tagged = replace(case, tags=_tags_for(target, case))
            if wanted <= tagged.tags:
                out.append(tagged)
    return out


def target_cases(target: str, case: str) -> list[Case]:
    if target == "chonsole":
        cases = [
            Case(
                name="chonsole-lua-baseline",
                flags={"chonsole": "lua", "ui": "chili"},
                scenario="chonsole_editing",
            ),
            Case(
                name="chonsole-rust-port",
                flags={"chonsole": "rust", "ui": "chili"},
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
                flags={"chonsole": "lua", "ui": "chili"},
                scenario="main_panel_tabs",
                crop="right-panel",
            ),
            Case(
                name="main-panel-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="main_panel_tabs",
                crop="right-panel",
            ),
            Case(
                name="main-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="main_panel_tabs",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:2]
        return cases
    if target == "lighting-panel":
        cases = [
            Case(
                name="lighting-panel-lua-chili",
                flags={"chonsole": "lua", "ui": "chili"},
                scenario="lighting_panel",
                crop="right-panel",
            ),
            Case(
                name="lighting-panel-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="lighting_panel",
                crop="right-panel",
            ),
            Case(
                name="lighting-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="lighting_panel",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:2]
        return cases
    if target in ("sky-panel", "water-panel"):
        scenario = target.replace("-", "_")
        return [
            Case(
                name=f"{target}-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario=scenario,
                crop=None if target == "water-panel" else "right-panel",
            )
        ]
    if target == "units-panel":
        cases = [
            Case(
                name="units-panel-lua-chili",
                flags={"chonsole": "lua", "ui": "chili"},
                scenario="units_panel",
                crop="right-panel",
            ),
            Case(
                name="units-panel-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="units_panel",
                crop="right-panel",
            ),
            Case(
                name="units-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="units_panel",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:2]
        return cases
    if target == "teams-panel":
        cases = [
            Case(
                name="teams-panel-lua-chili",
                flags={"chonsole": "lua", "ui": "chili"},
                scenario="teams_panel",
                crop="right-panel",
            ),
            Case(
                name="teams-panel-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="teams_panel",
                crop="right-panel",
            ),
            Case(
                name="teams-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="teams_panel",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:2]
        return cases
    if target == "info-panel":
        cases = [
            Case(
                name="info-panel-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="info_panel",
                crop="right-panel",
            ),
            Case(
                name="info-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="info_panel",
                crop="right-panel",
            ),
        ]
        return cases
    if target == "collision":
        return [
            Case(
                name="collision-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="collision",
            ),
        ]
    if target == "selection":
        return [
            Case(
                name="selection-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="selection",
            ),
        ]
    if target == "props-panel":
        return [
            Case(
                name="props-panel-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="props_panel",
                crop="right-panel",
            ),
            Case(
                name="props-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="props_panel",
                crop="right-panel",
            ),
        ]
    if target == "notifications":
        cases = [
            Case(
                name="notifications-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="notifications",
            ),
            Case(
                name="notifications-lua-chili",
                flags={"chonsole": "lua", "ui": "chili"},
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
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="heightmap",
            ),
            Case(
                name="heightmap-lua-chili",
                flags={"chonsole": "lua", "ui": "chili"},
                scenario="heightmap",
            ),
            Case(
                name="heightmap-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="heightmap",
            ),
        ]
        if case == "lua":
            return cases[1:2]
        if case == "rust":
            return cases[:1]
        return cases
    if target == "native-dev-console":
        return [
            Case(
                name="native-dev-console-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="native_dev_console",
                crop="dev-console",
            ),
        ]
    if target == "native-panel":
        return [
            Case(
                name="native-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="native_panel",
                crop="right-panel",
            ),
        ]
    if target == "map-editors":
        return [
            Case(
                name="map-editors-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="map_editors",
                crop="right-panel",
            ),
        ]
    if target == "all-editors":
        return [
            Case(
                name="all-editors-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="all_editors",
                crop="right-panel",
            ),
            Case(
                name="all-editors-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="all_editors",
                crop="right-panel",
            ),
        ]
    if target == "dialogs":
        return [
            Case(
                name="dialogs-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="dialogs",
            ),
        ]
    if target == "cursortip":
        return [
            Case(
                name="cursortip-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="cursortip",
            ),
        ]
    if target == "settings-panel":
        return [
            Case(
                name="settings-panel-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="settings_panel",
            ),
            Case(
                name="settings-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="settings_panel",
            ),
        ]
    if target == "dev-console":
        cases = [
            Case(
                name="dev-console-lua-chili",
                flags={"chonsole": "lua", "ui": "chili"},
                scenario="dev_console",
            ),
            Case(
                name="dev-console-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
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
                flags={"chonsole": "lua", "ui": "chili"},
                scenario="texture_panel",
                crop="right-panel",
            ),
            Case(
                name="texture-panel-lua-rmlui",
                flags={"chonsole": "lua", "ui": "rmlui"},
                scenario="texture_panel",
                crop="right-panel",
            ),
            Case(
                name="texture-panel-rust",
                flags={"chonsole": "rust", "ui": "rust"},
                scenario="texture_panel",
                crop="right-panel",
            ),
        ]
        if case == "lua":
            return cases[:1]
        if case == "rust":
            return cases[1:2]
        return cases
    raise ValueError(f"unknown target: {target}")
