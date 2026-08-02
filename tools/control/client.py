"""A connected session: the handles, over a connection."""

from collections.abc import Generator, Mapping
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from .errors import UNKNOWN_NAME_CODE, ConnectionClosedError, UnknownNameError
from .handles import Camera, Commands, Dialog, Editor, index_dialogs, index_editors
from .transport import CONNECT_TIMEOUT_S, Connection, open_connection, open_replacement_connection


class Control:
    """A connected editor session.

    `describe` is fetched once, at connect: the live editor is the only
    authority on what exists, since the set of editors depends on build flags
    and on whatever registers itself later.
    """

    def __init__(self, connection: Connection, write_dir: Path) -> None:
        self._connection = connection
        self._write_dir = write_dir
        schema = connection.call("describe")
        # Handles keep the Control facade, rather than the raw socket, so a
        # project reload can replace the socket without invalidating handles
        # that a caller declared before the reload.
        self._editors = index_editors(self, schema)
        self._dialogs = index_dialogs(self, schema)
        self.commands = Commands(self, schema["commands"])

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

    def dialog(self, name: str) -> Dialog:
        """Return the typed domain-input dialog registered under ``name``."""
        if name not in self._dialogs:
            raise UnknownNameError(
                UNKNOWN_NAME_CODE,
                f"no dialog {name!r}. Dialogs: {', '.join(sorted(self._dialogs))}",
            )
        return self._dialogs[name]

    @property
    def editors(self) -> Mapping[str, Editor]:
        return self._editors

    @property
    def dialogs(self) -> Mapping[str, Dialog]:
        return self._dialogs

    @property
    def camera(self) -> Camera:
        return Camera(self)

    # ── Calls ──

    def capture(self, path: Path | str) -> Path:
        """Capture the window. Returns once the image is on disk, and contains
        every call made before it on this connection."""
        target = Path(path).resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        self.call("capture", path=str(target))
        return target

    def reload_native_modules(self) -> None:
        """Reload native modules and reconnect to their replacement channel."""
        previous_instance_id = self.instance_id
        self._trigger_reload("runtime.reload_native_modules")
        self._reconnect_after_native_reload(previous_instance_id)

    def reset_session(self) -> int:
        """Undo native history, reload modules, and return the undo count."""
        previous_instance_id = self.instance_id
        result = self._trigger_reload("runtime.reset_session")
        self._reconnect_after_native_reload(previous_instance_id)
        return int(result.get("undone", 0))

    def _trigger_reload(self, method: str) -> dict[str, Any]:
        try:
            return self._connection.call(method)
        except ConnectionClosedError:
            # The command can tear down this socket before its acknowledgement
            # reaches the client. The replacement channel is handled by the
            # caller; never retry the lifecycle request itself.
            return {}

    def _reconnect_after_native_reload(
        self, previous_instance_id: str, *, timeout_s: float = CONNECT_TIMEOUT_S
    ) -> None:
        self.close()
        self._connection = open_replacement_connection(self._write_dir, previous_instance_id, timeout_s)
        schema = self._connection.call("describe")
        self._editors = index_editors(self, schema)
        self._dialogs = index_dialogs(self, schema)
        self.commands = Commands(self, schema["commands"])

    def wait_for_update(self) -> None:
        """Wait for native input already sent to be consumed."""
        self.call("runtime.barrier")

    def call(self, method: str, **params: object) -> dict[str, Any]:
        """One raw call, for a method with no handle in front of it yet."""
        try:
            return self._connection.call(method, **params)
        except ConnectionClosedError:
            # A project reload replaces the native module and closes every old
            # socket before publishing the replacement server. Calls made after
            # the UI has observed the reload should transparently use that new
            # channel; callers should not have to know about the module lifetime.
            previous_instance_id = self.instance_id
            self._reconnect_after_native_reload(previous_instance_id, timeout_s=15.0)
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
    return Control(open_connection(write_dir, timeout_s), write_dir)
