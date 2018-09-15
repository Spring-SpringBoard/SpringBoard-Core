const { exec } = require('child_process');
const { bridge } = require('../spring_api');

function getDefaultAppOpener() {
  switch (process.platform) {
    case 'darwin' : return 'open';
    case 'win32' : case 'win64': return 'start';
    default: return 'xdg-open';
  }
}

bridge.on("OpenFile", (command) => {
  const fullPath = getDefaultAppOpener() + ' ' + command.path;
  exec(fullPath, (err, stdout, stderr) => {
    if (err) {
      bridge.send("OpenedFileFailed", {
        path: command.path,
        stderr: stderr,
        stdout: stdout,
      });
    } else {
      bridge.send("OpenFileFinished", {
        path: command.path,
        stderr: stderr,
        stdout: stdout,
      });
    }
  });
  console.log(fullPath);
});
