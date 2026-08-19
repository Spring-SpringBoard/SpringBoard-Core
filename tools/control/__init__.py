"""Programmatic control of a running SpringBoard editor.

    with connect(write_dir) as sb:
        lighting = sb.editor("lightingEditor")
        sun = sb.commands["SetSunParametersCommand"]
        ...

`handles` is the surface a script works through, `transport` the socket and
discovery underneath it. Every name is resolved against the live editor's
schema when it is looked up, so a script declares its handles at the top and a
typo costs a connect rather than a run.

See docs/design/programmatic-control.md.
"""

from .client import Control, connect, connect_session
from .errors import ControlError, UnknownNameError
from .handles import Camera, Command, Commands, Dialog, Editor, FieldSpec

__all__ = [
    "Camera",
    "Command",
    "Commands",
    "Control",
    "ControlError",
    "Dialog",
    "Editor",
    "FieldSpec",
    "UnknownNameError",
    "connect",
    "connect_session",
]
