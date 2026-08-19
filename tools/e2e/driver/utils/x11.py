import re

from .process import run


def find_windows() -> list[str]:
    result = run("xdotool", "search", "--name", "Recoil", check=False)
    ids = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if ids:
        return ids
    result = run("xdotool", "search", "--name", "Spring", check=False)
    ids = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return ids or _spring_client_windows()


def spring_processes() -> dict[int, str]:
    result = run("ps", "-ef", check=False)
    processes: dict[int, str] = {}
    for line in result.stdout.splitlines():
        if "spring --isolation" not in line or "rg " in line:
            continue
        parts = line.split()
        if len(parts) > 1 and parts[1].isdigit():
            processes[int(parts[1])] = line
    return processes


def window_pid(window_id: str) -> int | None:
    result = run("xprop", "-id", window_id, "_NET_WM_PID", check=False)
    match = re.search(r"=\s*(\d+)", result.stdout)
    return int(match.group(1)) if match else None


def window_geometry(window_id: str) -> tuple[int, int]:
    values = window_geometry_values(window_id)
    try:
        return values["WIDTH"], values["HEIGHT"]
    except KeyError as err:
        raise RuntimeError(f"could not parse window geometry values: {values}") from err


def window_geometry_values(window_id: str) -> dict[str, int]:
    result = run("xdotool", "getwindowgeometry", "--shell", window_id)
    values: dict[str, int] = {}
    for line in result.stdout.splitlines():
        key, _, value = line.partition("=")
        if value.lstrip("-").isdigit():
            values[key] = int(value)
    return values


def _spring_client_windows() -> list[str]:
    """Find the engine window without traversing the whole X11 window tree."""
    result = run("xprop", "-root", "_NET_CLIENT_LIST", check=False)
    client_ids = re.findall(r"0x[0-9a-fA-F]+", result.stdout)
    spring_pids = set(spring_processes())
    return [window_id for window_id in client_ids if window_pid(window_id) in spring_pids]
