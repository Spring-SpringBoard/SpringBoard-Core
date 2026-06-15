"""Boot SBC against the local dev engine and return the write dir.

Standalone use:
    python -m run_sbc           # boot once, print write-dir path

Library use:
    from run_sbc import boot
    write_dir = boot()
    (write_dir / "infolog.txt").read_text()
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from textwrap import dedent


SBC_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_ENGINE_DIR = Path("/home/gajop/projects/spring-projects/spring-bar/build-linux/install")
DEFAULT_TIMEOUT_S = 45

# If the heartbeat file goes this long without an update while in-engine tests
# run, treat the run as hung and kill it. Generous vs the per-test 5s internal
# timeouts.
HEARTBEAT_STALE_S = 20.0


def boot(
    *,
    engine_dir: Path = DEFAULT_ENGINE_DIR,
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

    Raises RuntimeError if the engine binary or native plugin is missing.
    Does NOT raise on engine exit code — timeout-kill is the normal path.
    """
    spring_bin = engine_dir / "spring"
    if not spring_bin.is_file() or not os.access(spring_bin, os.X_OK):
        raise RuntimeError(f"no executable spring binary at {spring_bin}")

    native_plugin = sbc_root / "native" / "target" / "release" / "librust_plugin.so"
    if not native_plugin.is_file():
        raise RuntimeError(
            f"native plugin not built at {native_plugin}\n"
            f"run `cargo build --release` in {sbc_root}/native first"
        )

    write_dir = Path(tempfile.mkdtemp(prefix="sbc-smoke-"))
    (write_dir / "games").mkdir()
    (write_dir / "games" / "SpringBoard Core.sdd").symlink_to(sbc_root)

    (write_dir / "springsettings.cfg").write_text(
        "Sound = 0\nFullscreen = 0\nXResolution = 800\nYResolution = 600\n"
    )

    # Two teams in two ally-teams so team/alliance integration tests have
    # something to act on (set_ally, change_player_team, get_team_info).
    (write_dir / "script.txt").write_text(
        dedent(
            """\
            [GAME]
            {
              GameType=SpringBoard Core $VERSION;
              MapName=sb_initial_blank_10x8;
              MapSeed=1;
              IsHost=1;
              MyPlayerName=Smoke;
              NumPlayers=1;
              [MAPOPTIONS] { new_map_x=10; new_map_y=8; }
              [PLAYER0] { Name=Smoke; Team=0; Spectator=1; }
              [TEAM0]   { TeamLeader=0; AllyTeam=0; }
              [TEAM1]   { TeamLeader=0; AllyTeam=1; }
              [ALLYTEAM0] { NumAllies=0; }
              [ALLYTEAM1] { NumAllies=0; }
            }
            """
        )
    )

    env = os.environ.copy()
    env["SPRING_NATIVE_MODULE"] = str(native_plugin)

    heartbeat: Path | None = None
    if run_tests:
        spec_path = write_dir / "sbc_test_spec.json"
        spec_path.write_text(json.dumps({"tags": tags} if tags else {}))
        env["SBC_TEST_SPEC"] = str(spec_path)
        env["SBC_TEST_RESULTS"] = str(write_dir / "sbc_test_results.json")
        heartbeat = write_dir / "sbc_test_heartbeat"
        env["SBC_TEST_HEARTBEAT"] = str(heartbeat)

    cmd = [
        str(spring_bin),
        "--isolation",
        "--write-dir",
        str(write_dir),
        str(write_dir / "script.txt"),
    ]

    if run_tests:
        # The in-engine framework quits the engine when tests finish, so the
        # normal path exits fast. The heartbeat watchdog kills a real hang
        # (plugin stuck / crashed mid-test) without waiting out timeout_s.
        _run_with_heartbeat(cmd, env, heartbeat, timeout_s)
    else:
        try:
            subprocess.run(cmd, env=env, timeout=timeout_s, check=False)
        except subprocess.TimeoutExpired:
            pass

    return write_dir


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


def main() -> int:
    write_dir = boot()
    print(write_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
