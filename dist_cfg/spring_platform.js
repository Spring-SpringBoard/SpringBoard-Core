'use strict';

const log = require('electron-log');
const path = require('path');
const fs = require('fs');
const { app } = require('electron');
const { existsSync, mkdirSync } = fs;
const assert = require('assert');

const platformName = process.platform;

if (platformName === 'linux') {
	// AppImage mounts do not preserve setuid sandbox requirements for chrome-sandbox.
	// Force Chromium to use the non-setuid sandbox mode.
	app.commandLine.appendSwitch('no-sandbox');
	app.commandLine.appendSwitch('disable-setuid-sandbox');
}

const { config } = require('./launcher_config');
const { resolveWritePath } = require('./write_path');

var FILES_DIR = 'files';
FILES_DIR = path.resolve(`${__dirname}/../files`);
if (!existsSync(FILES_DIR)) {
	FILES_DIR = path.resolve(`${process.resourcesPath}/../files`);
}

function copyBundledPath(srcPath, dstPath) {
	const stat = fs.lstatSync(srcPath);
	if (stat.isDirectory()) {
		fs.cpSync(srcPath, dstPath, { recursive: true, force: true });
		return;
	}
	if (stat.isSymbolicLink()) {
		const resolved = fs.realpathSync(srcPath);
		const resolvedStat = fs.lstatSync(resolved);
		if (resolvedStat.isDirectory()) {
			fs.cpSync(resolved, dstPath, { recursive: true, force: true });
		} else {
			fs.copyFileSync(resolved, dstPath);
		}
		return;
	}
	fs.copyFileSync(srcPath, dstPath);
}

// The following order is necessary:
// 1. Set write dir
// 2. Set logfile based on the writedir
// 3. Start logging

assert(config.title != undefined);
const writePath = resolveWritePath(config.title);

assert(writePath != undefined);
if (!existsSync(writePath)) {
	try {
		mkdirSync(writePath);
	} catch (err) {
		log.error(`Cannot create writePath at: ${writePath}`);
		log.error(err);
	}
}

if (existsSync(FILES_DIR) && existsSync(writePath)) {
	fs.readdirSync(FILES_DIR).forEach(function (entry) {
		const srcPath = path.join(FILES_DIR, entry);
		const dstPath = path.join(writePath, entry);
		try {
			copyBundledPath(srcPath, dstPath);
		} catch (err) {
			log.error(`Failed to copy bundled path from ${srcPath} to ${dstPath}`);
			log.error(err);
		}
	});
}

let prDownloaderBin;
let butlerBin;
if (platformName === 'win32') {
	prDownloaderBin = 'pr-downloader.exe';
	butlerBin = 'butler/windows/butler.exe';
	exports.springBin = 'spring.exe';
} else if (platformName === 'linux') {
	prDownloaderBin = 'pr-downloader';
	butlerBin = 'butler/linux/butler';
	exports.springBin = 'spring';
	// } else if (platformName === 'darwin') {
	// 	prDownloaderBin = 'pr-downloader-mac';
	// 	butlerBin = 'butler'; // TODO: Support Mac?
	// 	exports.springBin = 'Contents/MacOS/spring';
} else {
	log.error(`Unsupported platform: ${platformName}`);
	process.exit(-1);
}

exports.prDownloaderPath = path.resolve(`${__dirname}/../bin/${prDownloaderBin}`);
if (!existsSync(exports.prDownloaderPath)) {
	exports.prDownloaderPath = path.resolve(`${process.resourcesPath}/../bin/${prDownloaderBin}`);
}
exports.butlerPath = path.resolve(`${__dirname}/../bin/${butlerBin}`);
if (!existsSync(exports.butlerPath)) {
	exports.butlerPath = path.resolve(`${process.resourcesPath}/../bin/${butlerBin}`);
}

exports.writePath = writePath;
