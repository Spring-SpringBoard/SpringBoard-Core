const EventEmitter = require('events');
const { spawn } = require('child_process');

const { bridge } = require('../spring_api');

class Compiler extends EventEmitter {
  constructor(bridge) {
    super();

    this.progressPattern = new RegExp('[0-9]+/\\s*[0-9]+');
    this.bridge = bridge;

    if (process.platform === 'windows') {
      this.executableName = "./springMapConvNG.exe";
    } else if (process.platform === 'linux') {
      this.executableName = "./springMapConvNG";
    }
  }

  compile(opts) {
    this.bridge.send("CompileMapStarted");
    // do async
    this.compileMap_SpringMapConvNG(opts);
  }

  compileMap_SpringMapConvNG(opts) {
    const callParams = [
        "-t", opts["diffusePath"],
        "-h", opts["heightPath"],
        "-ct", "1",
        "-o", opts["outputPath"]
    ]
    // proc = Popen(callParams, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    // for line in iter(proc.stdout.readline, ""):
    //     try:
    //         line = line.split("Compressing")[1]
    //         est, total = line.split("/")[0], line.split("/")[1]
    //         est = int(est.strip())
    //         total = int(total.strip().split()[0].strip())
    //     except Exception:
    //         pass
    //     else:
    //         self.sc.send({
    //             "name" : "UpdateCompiling",
    //             "command" : {
    //                 "est" : est,
    //                 "total" : total,
    //             }
    //         })
    //         #yield stdout_line
    // proc.stdout.close()
    // return_code = proc.wait()
    // stderr = proc.stderr.read()

    // const compilerPath = "./src/exts/springMapConvNG";
    // process = spawn('ls');

    process = spawn(`${__dirname}/${this.executableName}`, callParams);

    process.stdout.on('data', (data) => {
      const line = data.toString();
      console.log(line);
      if (line.includes("Compressing")) {
        const matched = line.match(this.progressPattern);
        if (!matched || matched.length == 0) {
          return;
        }
        var progressStr = matched[0];
        var [current, total] = progressStr.split("/");
        var current = parseInt(current);
        var total = parseInt(total);
        this.bridge.send("CompileMapProgress", {
          current: current,
          total: total
        });
      }
    });

    process.stderr.on('data', (data) => {
      console.log("stderr: ", data.toString());
    });

    process.on('exit', (code) => {
      console.log(`Exited: ${code}`);
      if (code == 0) {
        this.bridge.send("CompileMapFinished");
      } else {
        this.bridge.send("CompileMapError", {
            "code": code,
        });
      }
    });

    console.log("finished");
  }
}

const compiler = new Compiler(bridge);

bridge.on("CompileMap", (command) => {
  compiler.compile(command);
});
