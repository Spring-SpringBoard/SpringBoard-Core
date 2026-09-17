import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from typing import cast

SBC_ROOT = Path(__file__).resolve().parent.parent.parent
DEV_DIR = SBC_ROOT / "tools" / "dev"
DEFAULT_TIMEOUT_S = 45
HEARTBEAT_STALE_S = 20.0


def launch_manual(config: Path | None = None, project: str | None = None, scene: str | None = None) -> int:
    _, env, cmd = prepare_manual(config, project, scene)
    return subprocess.run(cmd, env=env, check=False).returncode


def launch_manual_detached(
    config: Path | None = None,
    project: str | None = None,
    scene: str | None = None,
    extra_env: dict[str, str] | None = None,
    screenshot_request: str | None = None,
    modoptions: dict[str, str] | None = None,
) -> tuple[subprocess.Popen[bytes], Path]:
    """Start a manual session without waiting for it.

    For harnesses that drive the running editor and need its write dir to read the
    infolog and hand it screenshot requests. `screenshot_request` names a file in
    the write dir that the engine polls for capture requests; it has to be in the
    environment before launch, so it is set here rather than by the caller.
    """
    write_dir, env, cmd = prepare_manual(config, project, scene, modoptions)
    if screenshot_request:
        env["SBC_E2E_SCREENSHOT_REQUEST"] = str(write_dir / screenshot_request)
    if extra_env:
        env.update(extra_env)
    return subprocess.Popen(cmd, env=env), write_dir


def manual_write_dir() -> Path:
    """The write dir a manual session uses, for callers that need it before launch."""
    return _manual_write_dir()


def prepare_manual(
    config: Path | None = None,
    project: str | None = None,
    scene: str | None = None,
    modoptions: dict[str, str] | None = None,
) -> tuple[Path, dict[str, str], list[str]]:
    write_dir, env, cmd = prepare(
        prefix="sbc-manual-",
        port_flags_config=config,
        write_dir=_manual_write_dir(),
    )
    if project:
        _open_project_on_boot(write_dir, project)
    options = dict(modoptions or {})
    if scene:
        options["sb_dev_scene"] = scene
    if options:
        _set_modoptions(write_dir, options)
    history_path = Path(env.setdefault("SBC_CHONSOLE_HISTORY", str(_manual_history_path())))
    print(f"write dir: {write_dir}")
    print(f"infolog:   {write_dir / 'infolog.txt'}")
    print(f"history:   {history_path}")
    if config is not None:
        print(f"config:    {config}")
    return write_dir, env, cmd


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
    game_dir = _stage_game_dir(sbc_root, write_dir)

    # The manual write dir is a fixed path reused across runs, so the previous
    # run's log is still there when the next one launches. Anything that waits on
    # a log marker polls the file before the engine has truncated it and matches
    # the *last* run's markers, so it stops waiting immediately. Removing it here,
    # before launch, makes "the marker is in the log" mean this run reached it.
    (write_dir / "infolog.txt").unlink(missing_ok=True)

    _link_fontcache(write_dir)
    (write_dir / "springsettings.cfg").write_text(_settings_text())
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


def _stage_game_dir(sbc_root: Path, write_dir: Path) -> Path:
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
    return game_dir


def _link_fontcache(write_dir: Path) -> None:
    fontcache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "sbc-fontcache"
    fontcache.mkdir(parents=True, exist_ok=True)
    fontcache_link = write_dir / "fontcache"
    fontcache_link.unlink(missing_ok=True)
    fontcache_link.symlink_to(fontcache)


def _settings_text() -> str:
    """The dev settings, with the window position overridable per run.

    The development window normally lives on the second monitor. Automated runs
    relocate it when that monitor is unavailable (a headless CI display, or the
    user's monitors being off), leaving the developer setting untouched on disk.
    """
    settings_text = (DEV_DIR / "springsettings.cfg").read_text()
    position_overrides = {
        "WindowPosX": os.environ.get("SBC_WINDOW_POS_X"),
        "WindowPosY": os.environ.get("SBC_WINDOW_POS_Y"),
        # Window size, for runs that only want pixels to measure. Offscreen runs draw through a
        # software rasteriser, where cost is close to linear in pixel count: a capture pass at the
        # developer's 2560x1371 spends about two seconds a frame, and most of that is resolution
        # the measurement never uses.
        "XResolutionWindowed": os.environ.get("SBC_WINDOW_W"),
        "YResolutionWindowed": os.environ.get("SBC_WINDOW_H"),
    }
    position_overrides = {key: value for key, value in position_overrides.items() if value}
    if not position_overrides:
        return settings_text
    for key, value in position_overrides.items():
        env_name = {
            "WindowPosX": "SBC_WINDOW_POS_X",
            "WindowPosY": "SBC_WINDOW_POS_Y",
            "XResolutionWindowed": "SBC_WINDOW_W",
            "YResolutionWindowed": "SBC_WINDOW_H",
        }[key]
        try:
            int(value)
        except ValueError as err:
            raise RuntimeError(f"{env_name} must be an integer") from err
    settings_lines = settings_text.splitlines(keepends=True)
    for key, value in position_overrides.items():
        for index, line in enumerate(settings_lines):
            if line.startswith(f"{key} ="):
                newline = "\n" if line.endswith("\n") else ""
                settings_lines[index] = f"{key} = {value}{newline}"
                break
        else:
            settings_lines.append(f"{key} = {value}\n")
    return "".join(settings_lines)


def _open_project_on_boot(write_dir: Path, project: str) -> None:
    """Load a project archive as a mutator, so the editor starts inside it.

    A project is a mutator over SpringBoard Core; opening one in the UI reloads with
    exactly this line added. Doing it at boot skips the navigation and, more usefully,
    means the project's featuredefs and gadgets exist from the first frame.
    """
    _append_to_game_block(write_dir, f"mutator0={project.removesuffix('.sdd')} 1.0;")


def _set_modoptions(write_dir: Path, options: dict[str, str]) -> None:
    """Write all modoptions as one block; the engine keeps only the last one."""
    body = " ".join(f"{key}={value};" for key, value in sorted(options.items()))
    _append_to_game_block(write_dir, f"[MODOPTIONS] {{ {body} }}")


def _append_to_game_block(write_dir: Path, line: str) -> None:
    """Insert a line just before the [GAME] block's closing brace.

    Anchored on the lone `}` line rather than the last brace in the file, so it
    stays correct once an earlier call has already added a nested block.
    """
    script = write_dir / "script.txt"
    lines = script.read_text().splitlines(keepends=True)
    closing = next((i for i in reversed(range(len(lines))) if lines[i].strip() == "}"), None)
    if closing is None:
        raise ValueError(f"{script} has no closing brace on its own line")
    lines.insert(closing, f"  {line}\n")
    script.write_text("".join(lines))


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
    raw_data = cast("dict[str, object]", data)
    allowed = {
        "chonsole": {"lua", "rust"},
        # The three UI implementations are independent: exactly one builds a UI.
        "ui": {"chili", "rmlui", "rust"},
    }
    for key, values in allowed.items():
        value = raw_data.get(key)
        if value not in values:
            expected = ", ".join(sorted(values))
            raise RuntimeError(f"{path}: {key} must be one of: {expected}")
    config_env = raw_data.get("env", {})
    if not isinstance(config_env, dict):
        raise RuntimeError(f"{path}: env must be a JSON object of name -> value")
    raw_env = cast("dict[object, object]", config_env)
    flags = {key: str(raw_data[key]) for key in allowed}
    return flags, {str(key): str(value) for key, value in raw_env.items()}


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
