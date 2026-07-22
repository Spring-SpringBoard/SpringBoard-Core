import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

SBC_ROOT = Path(__file__).resolve().parent.parent.parent
DEV_DIR = SBC_ROOT / "tools" / "dev"
DEFAULT_TIMEOUT_S = 45
HEARTBEAT_STALE_S = 20.0


def launch_manual(config: Path | None = None) -> int:
    write_dir, env, cmd = prepare(
        prefix="sbc-manual-",
        port_flags_config=config,
        write_dir=_manual_write_dir(),
    )
    history_path = Path(env.setdefault("SBC_CHONSOLE_HISTORY", str(_manual_history_path())))
    print(f"write dir: {write_dir}")
    print(f"infolog:   {write_dir / 'infolog.txt'}")
    print(f"history:   {history_path}")
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
    write_dir, env, cmd = prepare(
        engine_dir=engine_dir,
        sbc_root=sbc_root,
        run_tests=True,
        tags=tags,
        prefix="sbc-smoke-",
    )
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
    write_dir: Path | None = None,
) -> tuple[Path, dict[str, str], list[str]]:
    if engine_dir is None:
        engine_dir = _resolve_engine_dir()
    spring_bin = engine_dir / "spring"
    if not spring_bin.is_file() or not os.access(spring_bin, os.X_OK):
        raise RuntimeError(f"no executable spring binary at {spring_bin}")

    native_plugin = sbc_root / "native" / "target" / "release" / "librust_plugin.so"
    if not native_plugin.is_file():
        raise RuntimeError(
            f"native plugin not built at {native_plugin}\nrun `just build` (cargo build --release) in {sbc_root} first"
        )

    if write_dir is None:
        write_dir = Path(tempfile.mkdtemp(prefix=prefix))
    else:
        write_dir.mkdir(parents=True, exist_ok=True)
    (write_dir / "games").mkdir(exist_ok=True)
    game_dir = write_dir / "games" / "SpringBoard Core.sdd"
    if game_dir.exists():
        shutil.rmtree(game_dir)
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
            "artifacts",
            ".venv",
        ),
    )

    fontcache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "sbc-fontcache"
    fontcache.mkdir(parents=True, exist_ok=True)
    fontcache_link = write_dir / "fontcache"
    fontcache_link.unlink(missing_ok=True)
    fontcache_link.symlink_to(fontcache)

    shutil.copyfile(DEV_DIR / "springsettings.cfg", write_dir / "springsettings.cfg")
    shutil.copyfile(DEV_DIR / "script.txt", write_dir / "script.txt")
    config_env: dict[str, str] = {}
    if port_flags_config is not None:
        port_flags_config = port_flags_config.expanduser()
        if not port_flags_config.is_absolute():
            port_flags_config = sbc_root / port_flags_config
        flags, config_env = _read_port_flags_config(port_flags_config)
        flags_path = game_dir / "port_flags.json"
        flags_path.write_text(json.dumps(flags, indent=2, sort_keys=True) + "\n")

    env = os.environ.copy()
    env.update(config_env)
    _configure_lsan(env)
    env["SPRING_NATIVE_MODULE"] = str(native_plugin)
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


def _configure_lsan(env: dict[str, str]) -> None:
    existing = env.get("LSAN_OPTIONS", "")
    if "suppressions=" in existing:
        return
    options = (
        option
        for option in (
            existing,
            f"suppressions={Path(__file__).with_name('lsan.supp')}",
            "print_suppressions=0",
        )
        if option
    )
    env["LSAN_OPTIONS"] = ":".join(options)


def _manual_history_path() -> Path:
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    return state_home / "springboard" / "chonsole-history"


def _manual_write_dir() -> Path:
    override = os.environ.get("SBC_WRITE_DIR")
    if override:
        return Path(override).expanduser()
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    return data_home / "springboard" / "write-dir"


def _read_port_flags_config(path: Path) -> tuple[dict[str, str], dict[str, str]]:
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
    config_env = data.get("env", {})
    if not isinstance(config_env, dict):
        raise RuntimeError(f"{path}: env must be a JSON object of name -> value")
    flags = {key: str(data[key]) for key in allowed}
    return flags, {str(k): str(v) for k, v in config_env.items()}


def _run_with_heartbeat(cmd: list[str], env: dict[str, str], heartbeat: Path, hard_timeout_s: int) -> None:
    proc = subprocess.Popen(cmd, env=env)
    start = time.monotonic()
    try:
        while True:
            try:
                proc.wait(timeout=1.0)
                return
            except subprocess.TimeoutExpired:
                pass

            now = time.monotonic()
            if now - start > hard_timeout_s:
                break

            if heartbeat.is_file():
                age = time.time() - heartbeat.stat().st_mtime
                if age > HEARTBEAT_STALE_S:
                    break
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()


def _load_env_file(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip().strip("'\""))


def _resolve_engine_dir() -> Path:
    _load_env_file(SBC_ROOT / ".env")
    raw = os.environ.get("SBC_ENGINE_DIR")
    if not raw:
        raise RuntimeError(
            "SBC_ENGINE_DIR is not set. Copy .env.example to .env and point it at your spring engine install dir."
        )
    return Path(raw).expanduser()
