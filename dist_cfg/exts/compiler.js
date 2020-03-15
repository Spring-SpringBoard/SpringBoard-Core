const EventEmitter = require('events');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const log = require('electron-log');

const { bridge } = require('../spring_api');

class Compiler extends EventEmitter {
	constructor(bridge) {
		super();

		this.progressPattern = new RegExp('[0-9]+/\\s*[0-9]+');
		this.bridge = bridge;

		let executableBin;
		if (process.platform === 'win32') {
			executableBin = 'springMapConvNG.exe';
		} else if (process.platform === 'linux') {
			executableBin = 'springMapConvNG';
		} else {
			const errMsg = `Unsupported platform: ${process.platform}, cannot compile`;
			log.error(errMsg);
			this.bridge.send('CompileMapError', {
				'code': errMsg,
			});
			return;
		}

		this.executablePath = path.resolve(`${__dirname}/../../bin/${executableBin}`);
		if (!fs.existsSync(this.executablePath)) {
			this.executablePath = path.resolve(`${process.resourcesPath}/../bin/${executableBin}`);
		}
	}

	compile(opts) {
		this.bridge.send('CompileMapStarted');
		// do async
		this.compileMap_SpringMapConvNG(opts);
	}

	compileMap_SpringMapConvNG(opts) {
		var callParams = [
			'-t', opts['diffusePath'],
			'-h', opts['heightPath'],
			'-ct', '1', // TODO: allow customization?
			'-o', opts['outputPath']
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

		for (var k in extraParams) {
			if (k in opts) {
				callParams.push(extraParams[k], opts[k]);
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
					total: total
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
				this.bridge.send('CompileMapFinished');
			} else {
				this.bridge.send('CompileMapError', {
					'code': code,
					'msg': errorMsg
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
