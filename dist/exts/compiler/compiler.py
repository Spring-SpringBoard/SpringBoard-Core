import json
import subprocess
from subprocess import Popen

from connector import SpringConnector

class Compiler(object):
    def compileMap(self, command):
        self.sc.send({
            "name" : "StartCompiling"
        })
        success = self.compileMap_SpringMapConvNG(command)
        if success:
            self.sc.send({
                "name" : "FinishCompiling"
            })

    def compileMap_SpringMapConvNG(self, params):
        systemName = platform.system()
        if systemName == 'Windows':
            executableName = "./springMapConvNG.exe"
        elif systemName == 'Linux':
            executableName = "./springMapConvNG"
        callParams = [
            executableName,
                "-t", params["diffusePath"],
                "-h", params["heightPath"],
                "-ct", "1",
                "-o", params["outputPath"]
        ]
        proc = Popen(callParams, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        for line in iter(proc.stdout.readline, ""):
            try:
                line = line.split("Compressing")[1]
                est, total = line.split("/")[0], line.split("/")[1]
                est = int(est.strip())
                total = int(total.strip().split()[0].strip())
            except Exception:
                pass
            else:
                self.sc.send({
                    "name" : "UpdateCompiling",
                    "command" : {
                        "est" : est,
                        "total" : total,
                    }
                })
                #yield stdout_line
        proc.stdout.close()
        return_code = proc.wait()
        stderr = proc.stderr.read()
        if return_code:
            self.sc.send({
                "name" : "ErrorCompiling",
                "command" : {
                    "msg" : stderr,
                }
            })
            return False
        else:
            return True

    def register(self, connector):
        connector.register("CompileMap", self.compileMap)

