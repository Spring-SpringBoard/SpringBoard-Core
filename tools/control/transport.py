"""The plumbing: discovery file, authentication, and one JSON object per line
over a loopback socket. Knows nothing about editors, fields or commands."""

import json
import socket
import time
from collections.abc import Mapping
from pathlib import Path
from typing import Any

from .errors import UNKNOWN_NAME_CODE, ControlError, UnknownNameError

DISCOVERY_NAME = "control.json"
PROTOCOL_VERSION = 1
CONNECT_TIMEOUT_S = 60.0
CALL_TIMEOUT_S = 120.0


class Connection:
    """One authenticated connection. Calls block until the editor replies, and
    the editor only replies once the effect has landed."""

    def __init__(self, sock: socket.socket, instance_id: str) -> None:
        self._sock = sock
        self._stream = sock.makefile("rwb")
        self._next_id = 1
        self.instance_id = instance_id

    def call(self, method: str, **params: object) -> dict[str, Any]:
        request = {"jsonrpc": "2.0", "id": self._next_id, "method": method, "params": params}
        self._next_id += 1
        self._send(request)
        reply = self._receive()
        if "error" in reply:
            error = reply["error"]
            code, message = int(error.get("code", 0)), str(error.get("message", ""))
            raise (UnknownNameError if code == UNKNOWN_NAME_CODE else ControlError)(code, message)
        return dict(reply.get("result") or {})

    def close(self) -> None:
        self._stream.close()
        self._sock.close()

    def _send(self, payload: Mapping[str, object]) -> None:
        self._stream.write(json.dumps(payload).encode() + b"\n")
        self._stream.flush()

    def _receive(self) -> dict[str, Any]:
        line = self._stream.readline()
        if not line:
            raise ControlError(0, "the editor closed the control connection")
        return dict(json.loads(line))


def open_connection(write_dir: Path, timeout_s: float = CONNECT_TIMEOUT_S) -> Connection:
    """Find the session's socket, authenticate, and check it is the session the
    discovery file advertised."""
    discovery = _await_discovery(write_dir / DISCOVERY_NAME, timeout_s)
    if discovery.get("protocol_version") != PROTOCOL_VERSION:
        raise ControlError(
            0,
            f"editor speaks control protocol {discovery.get('protocol_version')}, client speaks {PROTOCOL_VERSION}",
        )
    sock = socket.create_connection((discovery["host"], int(discovery["port"])), timeout=timeout_s)
    sock.settimeout(CALL_TIMEOUT_S)
    instance_id = _authenticate(sock, str(discovery["token"]))
    # A crash leaves control.json behind, so the file alone does not prove which
    # session answered.
    if instance_id != discovery["instance_id"]:
        raise ControlError(0, f"connected to a different session: {instance_id} != {discovery['instance_id']}")
    return Connection(sock, instance_id)


def _authenticate(sock: socket.socket, token: str) -> str:
    stream = sock.makefile("rwb")
    hello = {"jsonrpc": "2.0", "id": 0, "method": "authenticate", "params": {"token": token}}
    stream.write(json.dumps(hello).encode() + b"\n")
    stream.flush()
    reply = json.loads(stream.readline() or "{}")
    stream.close()
    if "error" in reply:
        raise ControlError(int(reply["error"]["code"]), str(reply["error"]["message"]))
    return str(reply.get("result", {}).get("instance_id", ""))


def _await_discovery(path: Path, timeout_s: float) -> dict[str, Any]:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if path.is_file():
            try:
                return dict(json.loads(path.read_text()))
            except json.JSONDecodeError:
                pass
        time.sleep(0.05)
    raise ControlError(0, f"no control channel appeared at {path} within {timeout_s:.0f}s")
