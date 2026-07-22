from typing import Literal, TypedDict, cast

type CommandValue = str | int | float | bool | None | list[CommandValue] | dict[str, CommandValue]
type CommandFields = dict[str, CommandValue]


class PortFlags(TypedDict):
    chonsole: Literal["lua", "rust"]
    ui: Literal["chili", "rmlui", "rust"]


class CommandData(TypedDict, total=False):
    className: str
    __cmd_id: str | int
    __preview: bool
    opts: CommandFields
    commands: list["CommandData"]


class CommandEntry(TypedDict):
    data: CommandData


class WorldPosition(TypedDict):
    x: float
    y: float
    z: float


def parse_command_entry(value: object) -> CommandEntry | None:
    if not isinstance(value, dict):
        return None
    data = value.get("data")
    if not isinstance(data, dict):
        return None
    return {"data": cast(CommandData, data)}


def parse_world_position(value: CommandValue) -> WorldPosition | None:
    if not isinstance(value, dict):
        return None
    x = value.get("x")
    y = value.get("y")
    z = value.get("z")
    if not isinstance(x, int | float) or not isinstance(y, int | float) or not isinstance(z, int | float):
        return None
    return {"x": float(x), "y": float(y), "z": float(z)}
