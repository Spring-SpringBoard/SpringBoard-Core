const fs = require("fs");
const path = require("path");

module.exports = async function sbcAfterPack(context) {
  if (context.electronPlatformName !== "linux") {
    return;
  }

  const appOutDir = context.appOutDir;
  const executableName = context.packager.executableName;
  const launcherPath = path.join(appOutDir, executableName);
  const realBinaryPath = path.join(appOutDir, `${executableName}-bin`);

  if (!fs.existsSync(launcherPath)) {
    return;
  }

  if (!fs.existsSync(realBinaryPath)) {
    fs.renameSync(launcherPath, realBinaryPath);
  }

  const wrapper = `#!/bin/sh
set -eu
APPDIR="$(CDPATH= cd -- \\"$(dirname -- \\"$0\\")\\" && pwd)"
exec "$APPDIR/${executableName}-bin" --no-sandbox --disable-setuid-sandbox "$@"
`;

  fs.writeFileSync(launcherPath, wrapper, { encoding: "utf-8", mode: 0o755 });
  fs.chmodSync(launcherPath, 0o755);
};
