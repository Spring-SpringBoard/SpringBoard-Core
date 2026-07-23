from collections.abc import Callable
from typing import Literal, TypedDict, cast

type CommandValue = str | int | float | bool | None | list[CommandValue] | dict[str, CommandValue]
type CommandFields = dict[str, CommandValue]
type CommandData = CommandFields
type Environment = dict[str, str]


class PortFlags(TypedDict):
    chonsole: Literal["rust"]
    ui: Literal["rust"]


class CommandEntry(TypedDict):
    data: CommandData


class WorldPosition(TypedDict):
    x: float
    y: float
    z: float


def parse_command_entry(value: object) -> CommandEntry | None:
    if not isinstance(value, dict):
        return None
    raw = cast("dict[object, object]", value)
    data = raw.get("data")
    parsed = parse_command_value(data)
    if not isinstance(parsed, dict):
        return None
    return {"data": parsed}


def parse_command_value(value: object) -> CommandValue:
    if value is None or isinstance(value, str | int | float | bool):
        return value
    if isinstance(value, list):
        return [parse_command_value(item) for item in cast("list[object]", value)]
    if isinstance(value, dict):
        raw = cast("dict[object, object]", value)
        if all(isinstance(key, str) for key in raw):
            return {cast("str", key): parse_command_value(item) for key, item in raw.items()}
    raise TypeError(f"unsupported command JSON value: {value!r}")


def parse_world_position(value: CommandValue) -> WorldPosition | None:
    if not isinstance(value, dict):
        return None
    x = value.get("x")
    y = value.get("y")
    z = value.get("z")
    if not isinstance(x, int | float) or not isinstance(y, int | float) or not isinstance(z, int | float):
        return None
    return {"x": float(x), "y": float(y), "z": float(z)}


def number_close(expected: float, tolerance: float = 0.01) -> Callable[[CommandValue], bool]:
    return lambda value: isinstance(value, int | float) and abs(value - expected) < tolerance


def nonempty_string(value: CommandValue) -> bool:
    return isinstance(value, str) and bool(value)


def string_contains(text: str) -> Callable[[CommandValue], bool]:
    return lambda value: isinstance(value, str) and text in value


def string_starts_with(prefix: str) -> Callable[[CommandValue], bool]:
    return lambda value: isinstance(value, str) and value.startswith(prefix)


def list_first_is(expected: CommandValue) -> Callable[[CommandValue], bool]:
    return lambda value: isinstance(value, list) and bool(value) and value[0] == expected


def is_list(value: CommandValue) -> bool:
    return isinstance(value, list)


def is_object(value: CommandValue) -> bool:
    return isinstance(value, dict)


def object_has_key(key: str) -> Callable[[CommandValue], bool]:
    return lambda value: isinstance(value, dict) and key in value


def object_number_close(key: str, expected: float, tolerance: float = 0.01) -> Callable[[CommandValue], bool]:
    def matches(value: CommandValue) -> bool:
        if not isinstance(value, dict):
            return False
        actual = value.get(key)
        return isinstance(actual, int | float) and abs(actual - expected) < tolerance

    return matches


def object_number_above(key: str, minimum: float) -> Callable[[CommandValue], bool]:
    def matches(value: CommandValue) -> bool:
        if not isinstance(value, dict):
            return False
        actual = value.get(key)
        return isinstance(actual, int | float) and actual > minimum

    return matches


def object_number_below(key: str, maximum: float) -> Callable[[CommandValue], bool]:
    def matches(value: CommandValue) -> bool:
        if not isinstance(value, dict):
            return False
        actual = value.get(key)
        return isinstance(actual, int | float) and actual < maximum

    return matches
