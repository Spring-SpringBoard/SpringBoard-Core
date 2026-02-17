from __future__ import annotations

import shutil
from pathlib import Path
from typing import Annotated, Any

import typer

from .json_io import read_json_dict, write_json_dict
from .models import DistConfig

app = typer.Typer(add_completion=False, no_args_is_help=True)
JsonMap = dict[str, Any]
AFTER_PACK_HOOK_REL_PATH = "build/sbc_after_pack.cjs"
AFTER_PACK_HOOK_TEMPLATE = Path(__file__).resolve().parent / "assets" / "sbc_after_pack.cjs"


@app.command(name="make-package-json")
def make_package_json_command(
    package_json: Annotated[Path, typer.Argument(...)],
    config_json: Annotated[Path, typer.Argument(...)],
    repo_full_name: Annotated[str, typer.Argument(...)],
    version: Annotated[str, typer.Argument(...)],
) -> None:
    make_package_json(
        package_json=package_json,
        config_json=config_json,
        repo_full_name=repo_full_name,
        version=version,
    )


def make_package_json(package_json: Path, config_json: Path, repo_full_name: str, version: str) -> None:
    resolved_package_json = package_json.resolve()
    config = DistConfig.model_validate(read_json_dict(config_json.resolve()))
    package_template = read_json_dict(resolved_package_json)

    title = config.title
    repo_dot_name = repo_full_name.replace("/", ".")

    package_template["name"] = title.replace(" ", "-")
    build = ensure_dict(package_template, "build")
    build["artifactName"] = f"{title}-${{version}}.${{ext}}"
    package_template["version"] = version
    package_template["repository"] = f"github:{repo_full_name}"
    build["appId"] = f"com.springrts.launcher.{repo_dot_name}"
    build["afterPack"] = AFTER_PACK_HOOK_REL_PATH
    build.pop("publish", None)

    merge_dependencies(package_template, config.dependencies)
    ensure_packaged_files(build)

    write_json_dict(resolved_package_json, package_template, pretty=False)
    copy_after_pack_hook(resolved_package_json.parent / AFTER_PACK_HOOK_REL_PATH)


def merge_dependencies(package_template: JsonMap, dependencies: dict[str, str] | None) -> None:
    package_dependencies = ensure_dict(package_template, "dependencies")
    if dependencies is None:
        return
    for dependency_name, dependency_value in dependencies.items():
        package_dependencies[dependency_name] = dependency_value


def ensure_packaged_files(build: JsonMap) -> None:
    append_if_missing(ensure_list(build, "extraFiles"), "files/**")
    linux = ensure_dict(build, "linux")
    append_if_missing(ensure_list(linux, "extraFiles"), "files/**")
    win = ensure_dict(build, "win")
    append_if_missing(ensure_list(win, "extraFiles"), "files/**")


def ensure_dict(parent: JsonMap, key: str) -> JsonMap:
    value = parent.get(key)
    if isinstance(value, dict):
        return value
    parent[key] = {}
    return parent[key]


def ensure_list(parent: JsonMap, key: str) -> list[Any]:
    value = parent.get(key)
    if isinstance(value, list):
        return value
    parent[key] = []
    return parent[key]


def append_if_missing(values: list[Any], value: str) -> None:
    if value not in values:
        values.append(value)


def copy_after_pack_hook(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(AFTER_PACK_HOOK_TEMPLATE, path)


def main() -> None:
    app()
