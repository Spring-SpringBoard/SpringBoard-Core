import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class ApplicationConfig:
    launch: dict[str, Any]
    springsettings: dict[str, Any]


def read_application_config(path: Path) -> ApplicationConfig:
    with path.open("r", encoding="utf-8") as source:
        data = json.load(source)
    if not isinstance(data, dict):
        raise RuntimeError(f"Distribution configuration must be an object: {path}")
    return ApplicationConfig(
        launch=require_object(data, "launch"),
        springsettings=require_object(data, "springsettings"),
    )


def render_start_script(game_name: str, launch: dict[str, Any]) -> str:
    map_name = require_string(launch, "map")
    game_options = render_game_options(launch.get("game_options"))
    map_options = render_options_block("MapOptions", launch.get("map_options"))
    return (
        "[GAME]\n"
        "{\n"
        f"\tGameType = {game_name};\n"
        f"\tMapName = {map_name};\n"
        "\tHostIP = 127.0.0.1;\n"
        "\tIsHost = 1;\n"
        "\tNumPlayers = 2;\n"
        "\tNumUsers = 2;\n"
        "\tGameStartDelay = 0;\n\n"
        f"{game_options}\n\n"
        "\t[allyTeam0]\n\t{\n\t\tNumAllies = 0;\n\t}\n\n"
        "\t[allyTeam1]\n\t{\n\t\tNumAllies = 0;\n\t}\n\n"
        f"{map_options}\n\n"
        "\t[player0]\n\t{\n\t\tIsFromDemo = 1;\n\t\tName = Enemy;\n"
        "\t\tSpectator = 0;\n\t\tTeam = 1;\n\t}\n\n"
        "\t[player1]\n\t{\n\t\tIsFromDemo = 1;\n\t\tName = 0;\n"
        "\t\tSpectator = 0;\n\t\tTeam = 0;\n\t}\n\n"
        "\t[team0]\n\t{\n\t\tAllyTeam = 0;\n\t\tRGBColor = 0.35294119 0.35294119 1;\n"
        "\t\tTeamLeader = 0;\n\t}\n\n"
        "\t[team1]\n\t{\n\t\tAllyTeam = 1;\n\t\tRGBColor = 0.78431374 0 0;\n"
        "\t\tTeamLeader = 0;\n\t}\n"
        "}\n"
    )


def write_springsettings(settings: dict[str, Any], destination: Path) -> Path:
    values = {**settings, "DefaultStartScript": "script.txt"}
    output = destination / "springsettings.cfg"
    lines = [f"{key}={format_setting(value)}" for key, value in sorted(values.items())]
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output


def require_object(values: dict[str, Any], key: str) -> dict[str, Any]:
    value = values.get(key)
    if not isinstance(value, dict):
        raise RuntimeError(f"Distribution configuration requires an object '{key}'")
    return value


def require_string(values: dict[str, Any], key: str) -> str:
    value = values.get(key)
    if not isinstance(value, str) or not value:
        raise RuntimeError(f"Launch configuration requires a non-empty '{key}' value")
    return value


def render_game_options(value: object) -> str:
    options = require_options(value, "game_options")
    return "\n".join(f"\t{key} = {render_value(item)};" for key, item in sorted(options.items()))


def render_options_block(name: str, value: object) -> str:
    options = require_options(value, name)
    if not options:
        return ""
    entries = "\n".join(f"\t\t{key} = {render_value(item)};" for key, item in sorted(options.items()))
    return f"\t[{name}]\n\t{{\n{entries}\n\t}}"


def require_options(value: object, name: str) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise RuntimeError(f"Launch configuration '{name}' must be an object")
    return value


def render_value(value: object) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, (int, float)):
        return str(value)
    return json.dumps(value, separators=(",", ":"))


def format_setting(value: object) -> str:
    if isinstance(value, bool):
        return "1" if value else "0"
    return str(value)
