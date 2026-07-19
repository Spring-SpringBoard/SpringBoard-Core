-- Core module for SpringBoard
-- Authors: gajop

local modinfo = {
	name			= "SpringBoard Core",
	shortName		= "SB_C",
	version			= "$VERSION",
	mutator			= "Official",
	description		= "Core module of SpringBoard",
	modtype			= 1,
	onlyLocal		= true,
	nativeModule	= "native/rust_plugin",
	depend = {
		"Spring Cursors",
	}
}

return modinfo
