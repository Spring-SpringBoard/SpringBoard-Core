"""Boot SBC against the local dev engine.

Single source of truth for how SBC is launched: `prepare()` sets up the isolated
write dir (games symlink, persistent fontcache, dev config, native-plugin env)
and returns the spring command; everything else builds on it.

Standalone use:
    python -m run_sbc           # boot once (timed), print the write-dir path
    python -m run_sbc --manual  # interactive editor session (replaces launch.sh)
    python -m run_sbc --manual --config config/luaui-rmlui.json

Library use:
    from run_sbc import boot
    write_dir = boot()
    (write_dir / "infolog.txt").read_text()
"""

from __future__ import annotations

import json
import os
import argparse
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


SBC_ROOT = Path(__file__).resolve().parent.parent.parent
# Shared launch config, also used by tools/dev/launch.sh — single source of truth.
DEV_DIR = SBC_ROOT / "tools" / "dev"
DEFAULT_TIMEOUT_S = 45

# If the heartbeat file goes this long without an update while in-engine tests
# run, treat the run as hung and kill it. Generous vs the per-test 5s internal
# timeouts.
HEARTBEAT_STALE_S = 20.0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manual", action="store_true")
    parser.add_argument(
        "--config",
        type=Path,
        help="Port-flags JSON preset to copy into the isolated game as port_flags.json.",
    )
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    if args.manual:
        return launch_manual(config=args.config)
    write_dir = boot(tags=["__startup_only__"])
    print(write_dir)
    return 0


def launch_manual(config: Path | None = None) -> int:
    """Set up an isolated write dir and run SBC in the foreground until quit.

    The interactive twin of `boot()` — no timeout, no test spec. This is the whole
    body of the old tools/dev/launch.sh; that script now just calls it.
    """
    write_dir, env, cmd = prepare(prefix="sbc-manual-", port_flags_config=config)
    print(f"write dir: {write_dir}")
    print(f"infolog:   {write_dir / 'infolog.txt'}")
    if config is not None:
        print(f"config:    {config}")
    return subprocess.run(cmd, env=env, check=False).returncode


def boot(
    *,
    engine_dir: Path | None = None,
    timeout_s: int = DEFAULT_TIMEOUT_S,
    sbc_root: Path = SBC_ROOT,
    tags: list[str] | None = None,
) -> Path:
    """Boot SBC, run the requested tests, and return the write dir (with infolog.txt).

    Every boot goes through the in-engine test framework so the engine ALWAYS
    quits itself from the Rust side (`system_control().quit()`) the moment it is
    done -- Python never waits out a timeout or has to SIGKILL. `tags` filters
    which tests run (a tag substring); `None` runs the full suite, and a tag that
    matches nothing (e.g. `["__startup_only__"]`) runs zero tests so the engine
    quits as soon as startup finishes. The heartbeat watchdog only fires on a
    genuine hang.
    """
    write_dir, env, cmd = prepare(
        engine_dir=engine_dir,
        sbc_root=sbc_root,
        run_tests=True,
        tags=tags,
        prefix="sbc-smoke-",
    )
    # The framework quits the engine when it finishes (0 or more tests), so the
    # process exits on its own; the heartbeat watchdog only kills a real hang.
    _run_with_heartbeat(cmd, env, write_dir / "sbc_test_heartbeat", timeout_s)
    return write_dir


def prepare(
    *,
    engine_dir: Path | None = None,
    sbc_root: Path = SBC_ROOT,
    run_tests: bool = False,
    tags: list[str] | None = None,
    prefix: str = "sbc-",
    port_flags_config: Path | None = None,
) -> tuple[Path, dict[str, str], list[str]]:
    """Set up an isolated write dir and return (write_dir, env, spring command).

    The single place that knows how to launch SBC: creates the games symlink, the
    persistent fontcache symlink, copies the shared dev config, wires the
    native-plugin env, and (if `run_tests`) the in-engine test spec/results/
    heartbeat env. Both the test harness (`boot`) and the manual launcher
    (`launch_manual`, used by tools/dev/launch.sh) build on it.

    Raises RuntimeError if the engine binary or native plugin is missing.
    """
    if engine_dir is None:
        engine_dir = _resolve_engine_dir()
    spring_bin = engine_dir / "spring"
    if not spring_bin.is_file() or not os.access(spring_bin, os.X_OK):
        raise RuntimeError(f"no executable spring binary at {spring_bin}")

    native_plugin = sbc_root / "native" / "target" / "release" / "librust_plugin.so"
    if not native_plugin.is_file():
        raise RuntimeError(
            f"native plugin not built at {native_plugin}\n"
            f"run `just build` (cargo build --release) in {sbc_root} first"
        )

    write_dir = Path(tempfile.mkdtemp(prefix=prefix))
    (write_dir / "games").mkdir()
    game_dir = write_dir / "games" / "SpringBoard Core.sdd"
    shutil.copytree(
        sbc_root,
        game_dir,
        symlinks=True,
        ignore=shutil.ignore_patterns(
            ".git",
            ".mypy_cache",
            ".pytest_cache",
            ".ruff_cache",
            "target",
            "__pycache__",
            # e2e output lives in the repo and grows without bound (raw .xwd
            # captures). Copying it into every run's game dir made each temp
            # write dir ~8-11GB and compounded run over run.
            "artifacts",
            ".venv",
        ),
    )

    # The engine builds its fontconfig cache under <write_dir>/fontcache. Each
    # run uses a fresh temp dir, so without a persistent cache every launch pays a
    # ~20s font rescan. Point it at a shared dir, built once and reused.
    fontcache = (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "sbc-fontcache"
    )
    fontcache.mkdir(parents=True, exist_ok=True)
    (write_dir / "fontcache").symlink_to(fontcache)

    # Shared dev config (tools/dev/). Its script.txt sets up two teams in two
    # ally-teams so team/alliance tests have something to act on (set_ally,
    # change_player_team, get_team_info).
    shutil.copyfile(DEV_DIR / "springsettings.cfg", write_dir / "springsettings.cfg")
    shutil.copyfile(DEV_DIR / "script.txt", write_dir / "script.txt")
    if port_flags_config is not None:
        port_flags_config = port_flags_config.expanduser()
        if not port_flags_config.is_absolute():
            port_flags_config = sbc_root / port_flags_config
        flags = _read_port_flags_config(port_flags_config)
        flags_path = game_dir / "port_flags.json"
        flags_path.write_text(json.dumps(flags, indent=2, sort_keys=True) + "\n")

    env = os.environ.copy()
    env["SPRING_NATIVE_MODULE"] = str(native_plugin)
    # Trace every command Lua sends to Rust (one per line), next to the infolog.
    env["SBC_COMMAND_LOG"] = str(write_dir / "commands.jsonl")
    if run_tests:
        spec_path = write_dir / "sbc_test_spec.json"
        spec_path.write_text(json.dumps({"tags": tags} if tags else {}))
        env["SBC_TEST_SPEC"] = str(spec_path)
        env["SBC_TEST_RESULTS"] = str(write_dir / "sbc_test_results.json")
        env["SBC_TEST_HEARTBEAT"] = str(write_dir / "sbc_test_heartbeat")

    cmd = [
        str(spring_bin),
        "--isolation",
        "--write-dir",
        str(write_dir),
        str(write_dir / "script.txt"),
    ]
    return write_dir, env, cmd


def _read_port_flags_config(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise RuntimeError(f"run config does not exist: {path}")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as err:
        raise RuntimeError(f"invalid run config JSON at {path}: {err}") from err
    if not isinstance(data, dict):
        raise RuntimeError(f"run config must be a JSON object: {path}")
    allowed = {
        "chonsole": {"lua", "rust"},
        # The three UI implementations are independent: exactly one builds a UI.
        "ui": {"chili", "rmlui", "rust"},
    }
    for key, values in allowed.items():
        value = data.get(key)
        if value not in values:
            expected = ", ".join(sorted(values))
            raise RuntimeError(f"{path}: {key} must be one of: {expected}")
    return {key: str(data[key]) for key in allowed}


def _run_with_heartbeat(cmd, env, heartbeat: Path, hard_timeout_s: int) -> None:
    """Run the engine, killing it if the heartbeat goes stale or hard timeout.

    The in-engine test framework quits the engine itself when tests finish, so
    the usual exit is the process ending on its own. This only force-kills on a
    genuine hang.
    """
    proc = subprocess.Popen(cmd, env=env)
    start = time.monotonic()
    try:
        while True:
            try:
                proc.wait(timeout=1.0)
                return  # engine exited (normal: it self-quit after tests)
            except subprocess.TimeoutExpired:
                pass

            now = time.monotonic()
            if now - start > hard_timeout_s:
                break

            if heartbeat.is_file():
                age = time.time() - heartbeat.stat().st_mtime
                if age > HEARTBEAT_STALE_S:
                    break
            # Before the first heartbeat, rely on the hard timeout (the game
            # takes ~25s to load before tests run).
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()


def _load_env_file(path: Path) -> None:
    """Populate os.environ from a KEY=VALUE .env file (real env vars win)."""
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))


def _resolve_engine_dir() -> Path:
    """Engine install dir from SBC_ENGINE_DIR (env or .env). No hardcoded path."""
    _load_env_file(SBC_ROOT / ".env")
    raw = os.environ.get("SBC_ENGINE_DIR")
    if not raw:
        raise RuntimeError(
            "SBC_ENGINE_DIR is not set. Copy .env.example to .env and point it at "
            "your spring engine install dir."
        )
    return Path(raw).expanduser()


if __name__ == "__main__":
    sys.exit(main())
