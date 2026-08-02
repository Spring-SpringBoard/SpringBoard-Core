"""The surface: what a script holds and works through. One handle per thing the
editor offers, each resolved against the live schema when it is looked up."""

from collections.abc import Iterator, Mapping, Sequence
from dataclasses import dataclass
from typing import Any, Protocol, Self, cast, override

from .errors import INVALID_PARAMS_CODE, UNKNOWN_NAME_CODE, ControlError, UnknownNameError

FieldValue = float | int | str | bool | Sequence[float]


class Caller(Protocol):
    """What a handle needs from the connection, and nothing more."""

    def call(self, method: str, **params: object) -> dict[str, Any]: ...


@dataclass(frozen=True, slots=True)
class FieldSpec:
    name: str
    kind: str
    value: FieldValue
    options: tuple[str, ...] | None = None


class Editor:
    """One editor, with the fields its model declares.

    Assignment goes through the same commit path an accepted picker value does,
    and returns only once the editor has applied it.
    """

    def __init__(self, control: Caller, name: str, caption: str, tab: str, fields: Mapping[str, FieldSpec]) -> None:
        # Underscored, so `__setattr__` treats them as the handle's own
        # attributes rather than as editor fields.
        self._control = control
        self._name = name
        self._caption = caption
        self._tab = tab
        self._fields = dict(fields)

    @property
    def name(self) -> str:
        return self._name

    @property
    def caption(self) -> str:
        return self._caption

    @property
    def tab(self) -> str:
        return self._tab

    @property
    def fields(self) -> Mapping[str, FieldSpec]:
        return self._fields

    def open(self) -> Self:
        """Open this editor, returning once the panel actually shows it."""
        self._control.call("ui.open", editor=self.name)
        return self

    def get(self, field: str) -> FieldValue:
        self._spec(field)
        return self._control.call("ui.get", field=field)["value"]

    def set(self, field: str, value: FieldValue) -> FieldValue:
        spec = self._spec(field)
        _check_value(self.name, spec, value)
        return self._control.call("ui.set", field=field, value=_wire(value))["value"]

    def __getattr__(self, name: str) -> FieldValue:
        if name.startswith("_"):
            raise AttributeError(name)
        return self.get(name)

    @override
    def __setattr__(self, name: str, value: object) -> None:
        if name.startswith("_"):
            object.__setattr__(self, name, value)
            return
        self.set(name, cast("FieldValue", value))

    @override
    def __repr__(self) -> str:
        return f"Editor({self.name!r}, fields={sorted(self._fields)})"

    def _spec(self, field: str) -> FieldSpec:
        if field not in self._fields:
            raise UnknownNameError(
                UNKNOWN_NAME_CODE,
                f"no field {field!r} in editor {self.name!r}. Its fields: {', '.join(sorted(self._fields))}",
            )
        return self._fields[field]


class Dialog:
    """A domain-input dialog controlled without synthetic pointer/keyboard events."""

    def __init__(self, control: Caller, name: str, fields: Mapping[str, FieldSpec]) -> None:
        self._control = control
        self._name = name
        self._fields = dict(fields)

    @property
    def name(self) -> str:
        return self._name

    @property
    def fields(self) -> Mapping[str, FieldSpec]:
        return self._fields

    def open(self) -> Self:
        self._control.call("dialog.open", dialog=self.name)
        return self

    def get(self, field: str) -> FieldValue:
        self._spec(field)
        return self._control.call("dialog.get", dialog=self.name, field=field)["value"]

    def set(self, field: str, value: FieldValue) -> FieldValue:
        spec = self._spec(field)
        _check_value(self.name, spec, value)
        return self._control.call("dialog.set", dialog=self.name, field=field, value=_wire(value))["value"]

    def select(self, path: str) -> None:
        self._control.call("dialog.select", dialog=self.name, path=str(path))

    def accept(self) -> None:
        self._control.call("dialog.accept", dialog=self.name)

    def cancel(self) -> None:
        self._control.call("dialog.cancel", dialog=self.name)

    def _spec(self, field: str) -> FieldSpec:
        if field not in self._fields:
            raise UnknownNameError(
                UNKNOWN_NAME_CODE,
                f"no field {field!r} in dialog {self.name!r}. Its fields: {', '.join(sorted(self._fields))}",
            )
        return self._fields[field]

    @override
    def __repr__(self) -> str:
        return f"Dialog({self.name!r}, fields={sorted(self._fields)})"


class Command:
    """One registered editor command, called by keyword."""

    def __init__(self, control: Caller, class_name: str) -> None:
        self._control = control
        self.class_name = class_name

    def __call__(self, **fields: object) -> dict[str, Any]:
        return self._control.call("command.execute", className=self.class_name, **fields)

    @override
    def __repr__(self) -> str:
        return f"Command({self.class_name!r})"


class Commands:
    """The command registry, indexed by `className`."""

    def __init__(self, control: Caller, names: Sequence[str]) -> None:
        self._control = control
        self._names = list(names)

    def __getitem__(self, class_name: str) -> Command:
        if class_name not in self._names:
            raise UnknownNameError(
                UNKNOWN_NAME_CODE,
                f"no command {class_name!r}. Registered: {', '.join(self._names)}",
            )
        return Command(self._control, class_name)

    def __contains__(self, class_name: str) -> bool:
        return class_name in self._names

    def __iter__(self) -> Iterator[str]:
        return iter(self._names)


class Camera:
    def __init__(self, control: Caller) -> None:
        self._control = control

    def get(self) -> dict[str, Any]:
        return self._control.call("camera.get")

    def set(
        self,
        *,
        position: Sequence[float] | None = None,
        controller_position: Sequence[float] | None = None,
        direction: Sequence[float] | None = None,
        fov: float | None = None,
        height: float | None = None,
        angle: float | None = None,
        distance: float | None = None,
        target: Sequence[float] | None = None,
        transition: float = 0.0,
    ) -> dict[str, Any]:
        params: dict[str, object] = {"transition": transition}
        if position is not None:
            params["position"] = [float(v) for v in position]
        if controller_position is not None:
            params["controller_position"] = [float(v) for v in controller_position]
        if direction is not None:
            params["direction"] = [float(v) for v in direction]
        if fov is not None:
            params["fov"] = float(fov)
        if height is not None:
            params["height"] = float(height)
        if angle is not None:
            params["angle"] = float(angle)
        if distance is not None:
            params["distance"] = float(distance)
        if target is not None:
            params["target"] = [float(v) for v in target]
        return self._control.call("camera.set", **params)

    def zoom(
        self,
        factor: float,
        *,
        screen: Sequence[float] | None = None,
    ) -> dict[str, Any]:
        """Zoom through the engine camera API, optionally around a screen point."""
        params: dict[str, object] = {"factor": float(factor)}
        if screen is not None:
            params["screen"] = [float(value) for value in screen]
        return self._control.call("camera.zoom", **params)

    def trace_screen_ray(self, x: float, y: float) -> dict[str, Any]:
        """Trace a top-origin screen point onto the ground."""
        return self._control.call("camera.trace", screen=[float(x), float(y)])


def index_editors(control: Caller, schema: Mapping[str, Any]) -> dict[str, Editor]:
    editors: dict[str, Editor] = {}
    for tab in schema["tabs"]:
        for entry in tab["editors"]:
            fields = {
                field["name"]: FieldSpec(
                    field["name"],
                    field["kind"],
                    field["value"],
                    tuple(field["options"]) if field.get("options") else None,
                )
                for field in entry["fields"]
            }
            editors[entry["name"]] = Editor(control, entry["name"], entry["caption"], tab["name"], fields)
    return editors


def index_dialogs(control: Caller, schema: Mapping[str, Any]) -> dict[str, Dialog]:
    dialogs: dict[str, Dialog] = {}
    for entry in schema.get("dialogs", []):
        fields = {
            field["name"]: FieldSpec(
                field["name"],
                field["kind"],
                field["value"],
                tuple(field["options"]) if field.get("options") else None,
            )
            for field in entry.get("fields", [])
        }
        dialogs[entry["name"]] = Dialog(control, entry["name"], fields)
    return dialogs


def _check_value(editor: str, spec: FieldSpec, value: FieldValue) -> None:
    expected = {
        "number": (int, float),
        "text": (str,),
        "bool": (bool,),
        "color": (list, tuple),
    }[spec.kind]
    if not isinstance(value, expected):
        raise ControlError(
            INVALID_PARAMS_CODE,
            f"{editor}.{spec.name} is a {spec.kind} field, got {type(value).__name__}: {value!r}",
        )
    # A dropdown's value is a plain string, so an unlisted one would set
    # silently. The editor rejects it too; this just fails one hop earlier.
    if spec.options is not None and value not in spec.options:
        raise UnknownNameError(
            UNKNOWN_NAME_CODE,
            f"{editor}.{spec.name} does not accept {value!r}. Its options: {', '.join(spec.options)}",
        )


def _wire(value: FieldValue) -> object:
    if isinstance(value, (list, tuple)):
        return [float(channel) for channel in value]
    return value
