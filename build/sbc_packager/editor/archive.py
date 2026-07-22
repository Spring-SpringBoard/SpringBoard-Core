import json
import re
import shutil
import tempfile
from pathlib import Path
from typing import Literal

from ..shared.archive import write_game_archive
from ..shared.files import copy_repo_filtered

Platform = Literal["linux", "win32"]
SUPPORTED_IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png"}
PORT_FLAG_KEYS = ("chonsole", "ui")
VALID_PORT_FLAGS = {
    "chonsole": {"lua", "rust"},
    "ui": {"rmlui", "rust"},
}


def normalize_platform(platform: str) -> Platform:
    if platform not in {"linux", "win32"}:
        raise RuntimeError(f"Unsupported platform: {platform}")
    return "linux" if platform == "linux" else "win32"


def resolve_game_name(repo_root: Path, version: str) -> str:
    modinfo_path = repo_root / "modinfo.lua"
    modinfo_text = modinfo_path.read_text(encoding="utf-8")
    name = parse_modinfo_string_field(modinfo_text, "name")
    template = parse_modinfo_string_field(modinfo_text, "version")
    if name is None:
        raise RuntimeError(f"Expected string field 'name' in {modinfo_path}")
    if template is None:
        raise RuntimeError(f"Expected string field 'version' in {modinfo_path}")
    return f"{name} {template.replace('$VERSION', version)}".strip()


def prepare_game_archive(
    *,
    repo_root: Path,
    files_dir: Path,
    game_name: str,
    version: str,
    extra_top_level_excludes: set[str],
    native_plugin: Path,
    platform: Platform,
    run_config: Path,
    loading_image: Path | None = None,
) -> Path:
    game_archive = files_dir / "games" / f"{game_name}.sdz"
    game_archive.parent.mkdir(parents=True, exist_ok=True)
    game_archive.unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix="sbc-game-") as staging_root:
        game_dir = Path(staging_root) / f"{game_name}.sdd"
        game_dir.mkdir()
        copy_repo_filtered(repo_root, game_dir, extra_top_level_excludes)
        install_version(game_dir / "modinfo.lua", version)
        install_port_flags(resolve_run_config(repo_root, run_config), game_dir)
        if loading_image is not None:
            install_loading_image(loading_image, game_dir)
        install_native_plugin(native_plugin, game_dir, platform)
        write_game_archive(game_dir, game_archive)
    return game_archive


def find_engine_loading_image(engine_directory: Path) -> Path | None:
    base_directory = engine_directory / "base"
    if not base_directory.is_dir():
        return None
    candidates = sorted(
        path for path in base_directory.iterdir() if path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_SUFFIXES
    )
    preferred = base_directory / "RecoilEngine_4K.png"
    if preferred in candidates:
        return preferred
    return candidates[0] if candidates else None


def parse_modinfo_string_field(modinfo_text: str, field_name: str) -> str | None:
    pattern = rf"^\s*{re.escape(field_name)}\s*=\s*[\"']([^\"']+)[\"']"
    match = re.search(pattern, modinfo_text, flags=re.MULTILINE)
    return None if match is None else match.group(1)


def install_version(modinfo_path: Path, version: str) -> None:
    modinfo_text = modinfo_path.read_text(encoding="utf-8")
    if "$VERSION" not in modinfo_text:
        raise RuntimeError(f"Expected $VERSION placeholder in {modinfo_path}")
    modinfo_path.write_text(modinfo_text.replace("$VERSION", version), encoding="utf-8")


def resolve_run_config(repo_root: Path, run_config: Path) -> Path:
    resolved = run_config if run_config.is_absolute() else repo_root / run_config
    resolved = resolved.resolve()
    if not resolved.is_file():
        raise RuntimeError(f"Run configuration is missing: {resolved}")
    return resolved


def install_port_flags(run_config: Path, game_directory: Path) -> None:
    with run_config.open("r", encoding="utf-8") as source:
        config = json.load(source)
    if not isinstance(config, dict):
        raise RuntimeError(f"Run configuration must be an object: {run_config}")
    flags: dict[str, str] = {}
    for key in PORT_FLAG_KEYS:
        value = config.get(key)
        valid_values = VALID_PORT_FLAGS[key]
        if not isinstance(value, str) or value not in valid_values:
            choices = ", ".join(sorted(valid_values))
            raise RuntimeError(f"Invalid '{key}' in {run_config}: expected one of {choices}")
        flags[key] = value
    destination = game_directory / "port_flags.json"
    destination.write_text(json.dumps(flags, indent=2) + "\n", encoding="utf-8")


def install_loading_image(source: Path, game_directory: Path) -> None:
    if source.suffix.lower() not in SUPPORTED_IMAGE_SUFFIXES:
        raise RuntimeError(f"Unsupported loading-screen image: {source}")
    destination = game_directory / "bitmaps" / "loadpictures" / f"springboard{source.suffix.lower()}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def install_native_plugin(native_plugin: Path, game_directory: Path, platform: Platform) -> None:
    native_name = "librust_plugin.so" if platform == "linux" else "rust_plugin.dll"
    native_directory = game_directory / "native"
    native_directory.mkdir()
    shutil.copy2(native_plugin.resolve(), native_directory / native_name)
