const fs = require('fs');
const path = require('path');

const log = require('electron-log');

const { convertSBHeightmap } = require('./transform_sb_image');
const { importSBHeightmap } = require('./import_sb_image');

function runTest() {
	importSBHeightmap({
		inPath: './heightmap.png',
		outPath: './heightmap.data',
		min: -50,
		max: 70
	});
	convertSBHeightmap({
		inPath: './heightmap.data',
		outPath: './heightmap-out.png',
		width: 385,
		height: 641,
		min: -50,
		max: 70
	});
}

module.exports = {
	runTest: runTest
};
