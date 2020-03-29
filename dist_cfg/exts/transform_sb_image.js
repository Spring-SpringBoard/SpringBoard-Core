const fs = require('fs');
const path = require('path');

const { PNG } = require('pngjs3');

const { bridge } = require('../spring_api');
const { writePath } = require('../spring_platform');

bridge.on('ConvertSBHeightmap', (command) => {
	OnConvertSBHeightmap(command);
});

function OnConvertSBHeightmap(command) {
	try {
		convertSBHeightmap(command);
	} catch (err) {
		const msg = typeof(err) == 'string' ? err : err.message;
		bridge.send('CommandFailed', {
			error: `Failed to export heightmap with error: ${msg}`,
			id: command.id
		});
		return;
	}

	bridge.send('CommandFinished', {
		path: path.join(writePath, command.outPath),
		id: command.id
	});
}

function convertSBHeightmap(command) {
	const width = command.width;
	const height = command.height;
	const inPath = path.join(writePath, command.inPath);
	const outPath = path.join(writePath, command.outPath);
	const min = command.min;
	const max = command.max;

	const data = fs.readFileSync(inPath);
	const packSizeBytes = 4;

	if (data.length != width * height * packSizeBytes) {
		throw `Incorrect parameters specified for image, size: ${data.length} and ` +
		`width: ${width}, height: ${height} and packSizeBytes: ${packSizeBytes} bytes`;
	}

	const uint16Size = 2;
	const inputView = new DataView(data.buffer);
	var outBuffer = new Buffer(uint16Size * width * height);
	var bitmap = new Uint16Array(outBuffer.buffer);
	for (var x = 0; x < width; x++) {
		for (var y = 0; y < height; y++) {
			const idx = y * width + x;
			const inputIndex = x * height + y;
			const scaled = (inputView.getFloat32(inputIndex * 4, true) - min) / (max - min);
			bitmap[idx] = scaled * 65535;
		}
	}

	const png = new PNG({
		width: width,
		height: height,
		bitDepth: 16,
		colorType: 0,
		inputColorType: 0,
		inputHasAlpha: false
	});

	png.data = outBuffer;
	png.pack().pipe(fs.createWriteStream(outPath));
}

bridge.on('TransformSBImage', (command) => {
	OnTransformSBImage(command);
});

function OnTransformSBImage(command) {
	try {
		transformSBImage(command);
	} catch (err) {
		const msg = typeof(err) == 'string' ? err : err.message;
		bridge.send('CommandFailed', {
			error: `Failed to export image with error: ${msg}`,
			id: command.id
		});
		return;
	}

	bridge.send('CommandFinished', {
		path: path.join(writePath, command.outPath),
		id: command.id
	});
}

function transformSBImage(command) {
	const width = command.width;
	const height = command.height;
	const inPath = path.join(writePath, command.inPath);
	const outPath = path.join(writePath, command.outPath);
	const multiplier = command.multiplier;
	const packSize = command.packSize;

	let colorType = 2;
	if (command.colorType === 'rgb') {
		colorType = 2;
	} else if (command.colorType === 'greyscale') {
		colorType = 0;
	} else {
		throw `Unexpected color type: ${command.colorType}`;
	}

	const bitDepth = command.bitDepth;
	if (bitDepth != 8 && bitDepth != 16) {
		throw `Unexpected bitDepth: ${bitDepth}`;
	}
	const outputDataSize = bitDepth / 8;

	const data = fs.readFileSync(inPath);
	const packSizeBytes = packSize == 'float32' ? 4 : 1;

	if (data.length != width * height * packSizeBytes) {
		throw `Incorrect parameters specified for image: ${inPath}, size: ${data.length} and ` +
			`width: ${width}, height: ${height} and packSize: ${packSize}: ${packSizeBytes} bytes`;
	}

	const inputView = new DataView(data.buffer);
	var outBuffer = new Buffer(outputDataSize * width * height);
	var bitmap = bitDepth == 8 ? new Uint8Array(outBuffer.buffer) : new Uint16Array(outBuffer.buffer);
	for (var x = 0; x < width; x++) {
		for (var y = 0; y < height; y++) {
			const idx = y * width + x;
			const inputIndex = x * height + y;
			const point = packSizeBytes == 4 ? inputView.getFloat32(inputIndex * 4, true) : inputView.getUint8(inputIndex);
			const scaled = point * multiplier;
			bitmap[idx] = scaled * 255;
		}
	}

	const png = new PNG({
		width: width,
		height: height,
		bitDepth: bitDepth,
		colorType: colorType,
		inputColorType: 0,
		inputHasAlpha: false
	});

	png.data = outBuffer;
	png.pack().pipe(fs.createWriteStream(outPath));
}

module.exports = {
	convertSBHeightmap: convertSBHeightmap,
	transformSBImage: transformSBImage
};