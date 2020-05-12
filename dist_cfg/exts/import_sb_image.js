const fs = require('fs');
const path = require('path');

const log = require('electron-log');

const { PNG } = require('pngjs3');

const { bridge } = require('../spring_api');
const { writePath } = require('../spring_platform');

bridge.on('ImportSBHeightmap', (command) => {
	OnImportSBHeightmap(command);
});

function OnImportSBHeightmap(command) {
	try {
		importSBHeightmap(command);
	} catch (err) {
		const msg = typeof(err) == 'string' ? err : err.message;
		bridge.send('CommandFailed', {
			error: `Failed to import heightmap with error: ${msg}`,
			id: command.id
		});
		return;
	}
}

function importSBHeightmap(command) {
	const inPath = path.join(writePath, command.inPath);
	const outPath = path.join(writePath, command.outPath);
	const min = command.min;
	const max = command.max;
	const expectedWidth = command.width;
	const expectedHeight = command.height;

	fs.createReadStream(inPath)
		.pipe(new PNG({
			skipRescale: true
		}))
		.on('parsed', function() {
			const float32Size = 4;
			let outBuffer = new Buffer(float32Size * this.width * this.height);
			let bitmap = new Float32Array(outBuffer.buffer);

			if (this.width != expectedWidth || this.height != expectedHeight) {
				bridge.send('CommandFailed', {
					error: `Only images of exact heightmap size can be imported. Expected: ${expectedWidth}x${expectedHeight}. Actual: ${this.width}x${this.height}.`,
					id: command.id
				});
				return;
			}

			log.info(`Importing heightmap of size: ${this.width}x${this.height}...`);
			log.info(`Buffer size: ${this.data.length}`);
			log.info(`PNG depth: ${this.store.depth}`);

			const grayscaleData = this.grayscaleData();
			let scaleBy = 1 / 255.0;
			switch (this.store.depth) {
			case 8: scaleBy = 1 / 255.0;
				break;
			case 16: scaleBy = 1 / 65535.0;
				break;
			default:
				log.warn(`Unexpected png bit depth: ${this.store.depth}. Treating as 8-bit`);
			}
			for (let x = 0; x < this.width; x++) {
				for (let y = 0; y < this.height; y++) {
					const idx = this.width * y + x;
					const inputIndex = x * this.height + y;
					const heightmap = grayscaleData[idx] * scaleBy;
					bitmap[inputIndex] = min + heightmap * (max - min);
				}
			}

			fs.writeFileSync(outPath, outBuffer);

			bridge.send('CommandFinished', {
				path: path.join(writePath, command.outPath),
				id: command.id
			});
		});
}

module.exports = {
	importSBHeightmap: importSBHeightmap
};