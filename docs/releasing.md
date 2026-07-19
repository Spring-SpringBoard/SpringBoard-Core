# Releasing SpringBoard

The `SpringBoard release` workflow produces four files:

```text
SpringBoard-Core-<version>-linux-x86_64.sdz
SpringBoard-Core-<version>-windows-x86_64.sdz
SpringBoard-<version>-linux-x86_64.tar.gz
SpringBoard-<version>-windows-x86_64.zip
```

There are two `.sdz` files as SpringBoard Core itself uses Rust and builds different native binaries for each system.

The `.tar.gz` and `.zip` files are complete applications. They contain the engine, editor, settings, start script, and one executable named `SpringBoard` or `SpringBoard.exe`.

## Workflow inputs

- The compatible engine repository and release are committed in `build/distribution.json`.
- The Actions branch selector chooses the SpringBoard source to package.
- `publish`: off produces workflow artifacts only; on creates the tag and GitHub Release.

## Versions

- `stable`: `1.0.0`
- `prerelease`: `1.0.0-beta.1`
- `nightly`: generated as `YYYY-MM-DD-<short-sha>`

Existing tags and releases are never overwritten.
