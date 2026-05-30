"""Boot SBC against the local dev engine and return the write dir.

Standalone use:
    python -m run_sbc           # boot once, print write-dir path

Library use:
    from run_sbc import boot
    write_dir = boot()
    (write_dir / "infolog.txt").read_text()
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path
from textwrap import dedent


SBC_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_ENGINE_DIR = Path("/home/gajop/projects/spring-projects/spring-bar/build-linux/install")
DEFAULT_TIMEOUT_S = 45


def boot(
    *,
    engine_dir: Path = DEFAULT_ENGINE_DIR,
    timeout_s: int = DEFAULT_TIMEOUT_S,
    sbc_root: Path = SBC_ROOT,
) -> Path:
    """Boot SBC for `timeout_s` seconds, return the write dir (containing infolog.txt).

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
              [ALLYTEAM0] { NumAllies=0; }
            }
            """
        )
    )

    env = os.environ.copy()
    env["SPRING_NATIVE_MODULE"] = str(native_plugin)

    try:
        subprocess.run(
            [
                str(spring_bin),
                "--isolation",
                "--write-dir",
                str(write_dir),
                str(write_dir / "script.txt"),
            ],
            env=env,
            timeout=timeout_s,
            check=False,
        )
    except subprocess.TimeoutExpired:
        pass

    return write_dir


def main() -> int:
    write_dir = boot()
    print(write_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
