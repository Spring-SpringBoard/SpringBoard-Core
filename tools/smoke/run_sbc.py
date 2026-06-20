"""Boot SBC against the local dev engine.

Single source of truth for how SBC is launched: `prepare()` sets up the isolated
write dir (games symlink, persistent fontcache, dev config, native-plugin env)
and returns the spring command; everything else builds on it.

Standalone use:
    python -m run_sbc           # boot once (timed), print the write-dir path
    python -m run_sbc --manual  # interactive editor session (replaces launch.sh)

Library use:
    from run_sbc import boot
    write_dir = boot()
    (write_dir / "infolog.txt").read_text()
"""

from __future__ import annotations

import json
import os
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


def prepare(
    *,
    engine_dir: Path | None = None,
    sbc_root: Path = SBC_ROOT,
    run_tests: bool = False,
    tags: list[str] | None = None,
    prefix: str = "sbc-",
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
    (write_dir / "games" / "SpringBoard Core.sdd").symlink_to(sbc_root)

    # The engine builds its fontconfig cache under <write_dir>/fontcache. Each
    # run uses a fresh temp dir, so without a persistent cache every launch pays a
    # ~20s font rescan. Point it at a shared dir, built once and reused.
    fontcache = Path(
        os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")
    ) / "sbc-fontcache"
    fontcache.mkdir(parents=True, exist_ok=True)
    (write_dir / "fontcache").symlink_to(fontcache)

    # Shared dev config (tools/dev/). Its script.txt sets up two teams in two
    # ally-teams so team/alliance tests have something to act on (set_ally,
    # change_player_team, get_team_info).
    shutil.copyfile(DEV_DIR / "springsettings.cfg", write_dir / "springsettings.cfg")
    shutil.copyfile(DEV_DIR / "script.txt", write_dir / "script.txt")

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


def boot(
    *,
    engine_dir: Path | None = None,
    timeout_s: int = DEFAULT_TIMEOUT_S,
    sbc_root: Path = SBC_ROOT,
    run_tests: bool = False,
    tags: list[str] | None = None,
) -> Path:
    """Boot SBC for `timeout_s` seconds, return the write dir (containing infolog.txt).

    If `run_tests` is set, the in-engine test framework runs every registered
    test (via the `SBC_TEST_SPEC` env var), or only those whose tag contains any
    substring in `tags`; the plugin self-quits when done, and a heartbeat
    watchdog kills the run if it goes stale (a real hang) without waiting out the
    hard timeout.

    Does NOT raise on engine exit code — timeout-kill is the normal path.
    """
    write_dir, env, cmd = prepare(
        engine_dir=engine_dir,
        sbc_root=sbc_root,
        run_tests=run_tests,
        tags=tags,
        prefix="sbc-smoke-",
    )

    if run_tests:
        # The in-engine framework quits the engine when tests finish, so the
        # normal path exits fast. The heartbeat watchdog kills a real hang
        # (plugin stuck / crashed mid-test) without waiting out timeout_s.
        _run_with_heartbeat(cmd, env, write_dir / "sbc_test_heartbeat", timeout_s)
    else:
        try:
            subprocess.run(cmd, env=env, timeout=timeout_s, check=False)
        except subprocess.TimeoutExpired:
            pass

    return write_dir


def launch_manual() -> int:
    """Set up an isolated write dir and run SBC in the foreground until quit.

    The interactive twin of `boot()` — no timeout, no test spec. This is the whole
    body of the old tools/dev/launch.sh; that script now just calls it.
    """
    write_dir, env, cmd = prepare(prefix="sbc-manual-")
    print(f"write dir: {write_dir}")
    print(f"infolog:   {write_dir / 'infolog.txt'}")
    return subprocess.run(cmd, env=env, check=False).returncode


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


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if "--manual" in argv:
        return launch_manual()
    write_dir = boot()
    print(write_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
