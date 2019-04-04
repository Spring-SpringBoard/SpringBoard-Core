const {ipcRenderer} = require('electron');
const fs = require('fs');

ipcRenderer.on("TransformSBImage", (e, command) => {
	const width = command.width;
	const height = command.height;
	const inPath = command.inPath;
	const outPath = command.outPath;
	const multiplier = command.multiplier;
	const packSize = command.packSize;

	fs.readFile(inPath, function (err, data) {
	  if (err) {
		ipcRenderer.send("TransformSBImage", err);
		return;
	  }

	  var buffer = new Uint8ClampedArray(width * height * 4);
	  var view = new DataView(data.buffer);

	  for(var y = 0; y < height; y++) {
		for(var x = 0; x < width; x++) {
			const pos = (y * width + x) * 4;
			if (packSize == 'float32') {
			  buffer[pos  ] = view.getFloat32(x * height + y) * multiplier;
			} else {
			  buffer[pos  ] = data.buffer[x * height + y] * multiplier;
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