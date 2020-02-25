const fs = require('fs');
const path = require("path");

const { ipcRenderer } = require('electron');

const { PNG } = require("pngjs");

function convertSBHeightmap(inPath, outPath, width, height, min, max) {
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

// if (true) {
// 	exports.convertSBHeightmap = convertSBHeightmap;
// 	return;
// }

ipcRenderer.on("ConvertSBHeightmap", (e, command, writePath) => {
	const width = command.width;
	const height = command.height;
	const inPath = command.inPath;
	const outPath = path.join(writePath, command.outPath);
	const min = command.min;
	const max = command.max;
	try {
		convertSBHeightmap(inPath, outPath, width, height, min, max);
	} catch (err) {
		const msg = typeof(err) == "string" ? err : err.message;
		ipcRenderer.send("TransformSBImageFailed",
			`Failed to export heightmap with error: ${msg}`);
		return;
	}
	ipcRenderer.send("TransformSBImageFinished", outPath);
});

ipcRenderer.on("TransformSBImage", (e, command, writePath) => {
	const width = command.width;
	const height = command.height;
	const inPath = command.inPath;
	const outPath = path.join(writePath, command.outPath);
	const multiplier = command.multiplier;
	const packSize = command.packSize;

	fs.readFile(inPath, function (err, data) {
	    if (err) {
			ipcRenderer.send("TransformSBImageFailed", err);
			return;
		}

		var packSizeBytes;
		if (packSize == "float32") {
			packSizeBytes = 4;
		} else {
			packSizeBytes = 1;
		}

		if (data.length != width * height * packSizeBytes) {
			ipcRenderer.send("TransformSBImageFailed",
				`Incorrect parameters specified for image: ${inPath}, size: ${data.length} and ` +
				`width: ${width}, height: ${height} and packSize: ${packSize}: ${packSizeBytes} bytes`);
			return;
		}


	  var buffer = new Uint8ClampedArray(width * height * 4);
	  var view = new DataView(data.buffer);

	  for (var y = 0; y < height; y++) {
			for (var x = 0; x < width; x++) {
				const idx = y * width + x;
				const pos = idx * 4;
				if (packSize == 'float32') {
					buffer[pos  ] = view.getFloat32(idx * 4, true) * multiplier;
				} else {
					buffer[pos  ] = data[idx] * multiplier;
				}
				buffer[pos+1] = buffer[pos];
				buffer[pos+2] = buffer[pos];
				buffer[pos+3] = 255;
			}
	  }

	  var canvas = document.createElement('canvas'),
	  ctx = canvas.getContext('2d');

	  canvas.width = width;
	  canvas.height = height;

	  // create imageData object
	  var idata = ctx.createImageData(width, height);

	  // set our buffer as source
	  idata.data.set(buffer);

	  // update canvas with new data
	  ctx.putImageData(idata, 0, 0);

	  var url = canvas.toDataURL();
	  const base64Data = url.replace(/^data:image\/png;base64,/, "");
	  fs.writeFile(outPath, base64Data, 'base64', function (err) {
		if (err) {
		  ipcRenderer.send("TransformSBImage", err);
		  return;
		}
		ipcRenderer.send("TransformSBImageFinished", outPath);
	  });
	});
});