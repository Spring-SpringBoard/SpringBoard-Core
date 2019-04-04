const { ipcMain } = require('electron');

const { bridge } = require('../spring_api');
const { gui } = require('../launcher_gui.js');

bridge.on("TransformSBImage", (command) => {
	gui.send("TransformSBImage", command);
});

ipcMain.on("TransformSBImageFinished", (e, path) => {
	bridge.send("TransformSBImageFinished", {
		path: path
	});
});

ipcMain.on("TransformSBImageFailed", (e, error) => {
	bridge.send("TransformSBImageFailed", {
		error: error
	});
});