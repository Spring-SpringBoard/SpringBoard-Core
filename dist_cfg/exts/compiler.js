const EventEmitter = require('events');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const log = require('electron-log');

const { bridge } = require('../spring_api');
const { writePath } = require('../spring_platform');

class Compiler extends EventEmitter {
	constructor(bridge) {
		super();

		this.progressPattern = new RegExp('[0-9]+/\\s*[0-9]+');
		this.bridge = bridge;

		let executableBin;
		if (process.platform === 'win32') {
			executableBin = 'springMapConvNG.exe';
		} else if (process.platform === 'linux') {
			executableBin = 'mapcompile';
		} else {
			const errMsg = `Unsupported platform: ${process.platform}, cannot compile`;
			log.error(errMsg);
			return;
		}

		this.executablePath = path.resolve(`${__dirname}/../../bin/${executableBin}`);
		if (!fs.existsSync(this.executablePath)) {
			this.executablePath = path.resolve(`${process.resourcesPath}/../bin/${executableBin}`);
		}
	}

	compile(command) {
		this.bridge.send('CompileMapStarted', {
			id: command.id
		});
		// do async
		this.compileMap_SpringMapConvNG(command);
	}

	compileMap_SpringMapConvNG(command) {
		var callParams = [
			'-t', path.join(writePath, command['diffusePath']),
			'-h', path.join(writePath, command['heightPath']),
			'-ct', '1', // TODO: allow customization?
			'-o', path.join(writePath, command['outputPath'])
		];
		const extraParams = {
			'metalPath' : '-m',
			'typePath'  : '-z',
			'maxh' : '-maxh',
			'minh' : '-minh',
			'minimap' : '-minimap',

			// disable some potential footguns
			// "-ccount [compare_tilecount]",
			// "-th [compression_level]",
			// "-features [featurefile]"
		};

		for (let k in extraParams) {
			if (k in command) {
				if (k == 'metalPath' || k == 'typePath') {
					callParams.push(extraParams[k], path.join(writePath, command[k]));
				} else {
					callParams.push(extraParams[k], command[k]);
				}
			}
		}

		log.info(callParams);
		let compileProcess = spawn(this.executablePath, callParams);

		compileProcess.stdout.on('data', (data) => {
			const line = data.toString();
			console.log(line);
			if (line.includes('Compressing')) {
				const matched = line.match(this.progressPattern);
				if (!matched || matched.length == 0) {
					return;
				}
				var progressStr = matched[0];
				var [current, total] = progressStr.split('/');
				current = parseInt(current);
				total = parseInt(total);
				this.bridge.send('CompileMapProgress', {
					current: current,
					total: total,
					id: command.id
				});
			}
		});

		var errorMsg = '';
		compileProcess.stderr.on('data', (data) => {
			console.log('stderr: ', data.toString());
			errorMsg += data.toString() + '\n';
		});

		compileProcess.on('exit', (code) => {
			console.log(`Exited: ${code}`);
			if (code == 0) {
				this.bridge.send('CommandFinished', {
					id: command.id
				});
			} else {
				errorMsg += `Compilation failed with error code: ${code}`;
				this.bridge.send('CommandFailed', {
					error: errorMsg,
					id: command.id
				});
			}
		});

		console.log('finished');
	}
}

const compiler = new Compiler(bridge);

bridge.on('CompileMap', (command) => {
	compiler.compile(command);
});
