# SBC Packager

This folder contains the Python packager used by CD to produce a fully standalone SpringBoard build.

## Tooling

- Python: `3.13`
- Runner: `uv`
- CLI: `typer`
- Validation: `pydantic`
- Lint/typecheck: `ruff`, `pyright`

## Main command

Use `sbc-packager-package` to run the full packager pipeline:

1. Rewrite packaged config and game files (`prepare`)
2. Download and extract the platform engine (`download-engine`)
3. Generate Electron `package.json` (`make-package-json`)

The command requires explicit git-derived values from the caller:

- `--git-hash`
- `--package-version`

This keeps packager behavior deterministic and avoids hidden git subprocess logic inside the package tool.

## Local usage

From repository root:

```bash
git clone --depth 1 https://github.com/gajop/spring-launcher.git /tmp/spring-launcher

mkdir -p /tmp/sbc-local-build
cp -r /tmp/spring-launcher/* /tmp/sbc-local-build/
cp -r ./dist_cfg/* /tmp/sbc-local-build/src/
mkdir -p /tmp/sbc-local-build/{bin,files,build}
[ -d /tmp/sbc-local-build/src/bin/ ] && mv /tmp/sbc-local-build/src/bin/* /tmp/sbc-local-build/bin/
[ -d /tmp/sbc-local-build/src/files/ ] && mv /tmp/sbc-local-build/src/files/* /tmp/sbc-local-build/files/
[ -d /tmp/sbc-local-build/src/build/ ] && mv /tmp/sbc-local-build/src/build/* /tmp/sbc-local-build/build/
rm -rf /tmp/sbc-local-build/src/{bin,files,build}

GIT_HASH=$(git rev-parse --short=12 HEAD)
PACKAGE_VERSION=1.$(git rev-list --count HEAD).0

uv run --project ./build --locked sbc-packager-package \
  --repo-root . \
  --config-in ./dist_cfg/config.json \
  --config-out /tmp/sbc-local-build/src/config.json \
  --files-dir /tmp/sbc-local-build/files \
  --meta-out /tmp/sbc-local-build/build/package-assets.json \
  --package-json /tmp/sbc-local-build/package.json \
  --repo-full-name Spring-SpringBoard/SpringBoard-Core \
  --platform linux \
  --git-hash "$GIT_HASH" \
  --package-version "$PACKAGE_VERSION" \
  --linux-setup-id latest-linux \
  --windows-setup-id latest-win
```

`/tmp/sbc-local-build` must be a launcher build tree (same structure as CD creates in `./build` job workspace).

## Linting

```bash
uv run --project ./build --locked ruff check ./build/sbc_packager
uv run --project ./build --locked pyright ./build/sbc_packager
```

## Linux AppImage sandbox note

`make-package-json` injects `afterPack: build/sbc_after_pack.cjs`.
That hook rewrites the Linux launcher binary to ensure direct `AppImage` execution uses:

- `--no-sandbox`
- `--disable-setuid-sandbox`

without requiring users to pass flags manually.
