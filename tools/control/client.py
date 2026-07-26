"""A connected session: the handles, over a connection."""

from collections.abc import Generator, Mapping
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from .errors import UNKNOWN_NAME_CODE, UnknownNameError
from .handles import Camera, Commands, Editor, index_editors
from .transport import CONNECT_TIMEOUT_S, Connection, open_connection


class Control:
    """A connected editor session.

    `describe` is fetched once, at connect: the live editor is the only
    authority on what exists, since the set of editors depends on build flags
    and on whatever registers itself later.
    """

    def __init__(self, connection: Connection) -> None:
        self._connection = connection
        schema = connection.call("describe")
        self._editors = index_editors(connection, schema)
        self.commands = Commands(connection, schema["commands"])

    @property
    def instance_id(self) -> str:
        return self._connection.instance_id

    # ── Declaring handles ──

    def editor(self, name: str) -> Editor:
        """The editor registered under `name`, opened.

        Raises immediately if there is no such editor, which is why a script
        declares the ones it needs before doing anything else.
        """
        if name not in self._editors:
            raise UnknownNameError(
                UNKNOWN_NAME_CODE,
                f"no editor {name!r}. Editors: {', '.join(sorted(self._editors))}",
            )
        return self._editors[name].open()

    @property
    def editors(self) -> Mapping[str, Editor]:
        return self._editors

    @property
    def camera(self) -> Camera:
        return Camera(self._connection)

    # ── Calls ──

    def capture(self, path: Path | str) -> Path:
        """Capture the window. Returns once the image is on disk, and contains
        every call made before it on this connection."""
        target = Path(path).resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        self.call("capture", path=str(target))
        return target

    def call(self, method: str, **params: object) -> dict[str, Any]:
        """One raw call, for a method with no handle in front of it yet."""
        return self._connection.call(method, **params)

    def close(self) -> None:
        self._connection.close()

    def __enter__(self) -> "Control":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()


@contextmanager
def connect(write_dir: Path | str, timeout_s: float = CONNECT_TIMEOUT_S) -> Generator[Control]:
    """Attach to the editor session whose write dir this is."""
    control = connect_session(Path(write_dir), timeout_s)
    try:
        yield control
    finally:
        control.close()


def connect_session(write_dir: Path, timeout_s: float = CONNECT_TIMEOUT_S) -> Control:
    """Attach without owning the lifetime, for a caller that closes it itself."""
    return Control(open_connection(write_dir, timeout_s))
