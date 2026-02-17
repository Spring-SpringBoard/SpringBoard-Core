from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class EngineResource(BaseModel):
    url: str | None = None
    destination: str | None = None
    extract: bool | None = None

    model_config = ConfigDict(extra="allow")


class DownloadsConfig(BaseModel):
    games: list[str] | None = None
    maps: list[str] | None = None
    engines: list[str] | None = None
    resources: list[EngineResource] | None = None
    nextgen: list[Any] | None = None

    model_config = ConfigDict(extra="allow")


class LaunchConfig(BaseModel):
    game: str | None = None
    engine: str | None = None

    model_config = ConfigDict(extra="allow")


class PackageConfig(BaseModel):
    id: str | None = None
    platform: str | None = None

    model_config = ConfigDict(extra="allow")


class SetupConfig(BaseModel):
    package: PackageConfig = Field(default_factory=PackageConfig)
    downloads: DownloadsConfig = Field(default_factory=DownloadsConfig)
    launch: LaunchConfig = Field(default_factory=LaunchConfig)
    no_downloads: bool | None = None

    model_config = ConfigDict(extra="allow")


class DistConfig(BaseModel):
    title: str
    dependencies: dict[str, str] | None = None
    setups: list[SetupConfig] = Field(default_factory=list)

    model_config = ConfigDict(extra="allow")


class PackageAssetsMeta(BaseModel):
    gitHash: str
    gameName: str
    gameDirectory: str
    engineResource: EngineResource
    platform: Literal["linux", "win32"]
