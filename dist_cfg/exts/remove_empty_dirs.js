const fs = require('fs');
const path = require('path');

const { bridge } = require('../spring_api');
const { writePath } = require('../spring_platform');

bridge.on('RemoveEmptyDirs', (command) => {
	RemoveEmptyDirs(command);
});

function RemoveEmptyDirs(command) {
	try {
		let absPath = path.join(writePath, command.path);
		if (!IsDirTreeEmpty(absPath)) {
			throw 'Cannot delete directory. Directory tree is not empty.';
		}
		fs.rmdirSync(absPath, { recursive: true });
	} catch (err) {
		bridge.send('CommandFailed', {
			id: command.id,
			error: err
		});
		return;
	}

	bridge.send('CommandFinished', {
		id: command.id
	});
}

function IsDirTreeEmpty(dir) {
	for (const file of fs.readdirSync(dir)) {
		const filePath = path.join(dir, file);
		const stats = fs.statSync(filePath);
		if (stats.isDirectory()) {
			return IsDirTreeEmpty(filePath);
		} else {
			return false;
		}
	}
	return true;
}
