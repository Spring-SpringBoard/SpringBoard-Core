# SpringBoard packaging

The release packager produces:

- A platform-specific `.sdz` containing SpringBoard Core and its native plugin.
- A complete application containing the engine, editor, settings, and start
  script.

The complete application is built from an engine release `.7z`. Packaging
removes the AIs, unused engine executables, and their Windows import libraries,
then renames `spring` to `SpringBoard` or `SpringBoard.exe`. The application
build exports the exact `.sdz` embedded in the application as the standalone
editor artifact.

```bash
uv run --project build --locked sbc-packager-base --help
uv run --project build --locked sbc-packager-application --help
```

Linux applications use `.tar.gz`; Windows applications use `.zip`. Every
published file has a SHA-256 checksum.
