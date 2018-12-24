
VFS.Include(SPRINGMON_DIR .. "utils/shared.lua", nil, VFS.ZIP)

local absPathToVfsPath = {}

-- vfsFilePath -> { context1 = true, context2 = true... }
-- where context is one of: "widget", "gadget_synced", "gadget_unsynced")
local fileContextMap = {}

-- We won't update listeners until at least WAIT_TIME has passed after the last change
-- This can help prevent disasterous race conditions like reading a file that is being flushed to disk
local WAIT_TIME = 0.3
local fileChangedBuffer = {}
local lastChange = nil

-- TODO: belongs to a lib, like Path.Recurse or Path.Walk
local function Recurse(path, f, opts)
	opts = opts or {}
	for _, file in pairs(VFS.DirList(path), "*", opts.mode) do
		f(file)
	end
	for _, dir in pairs(VFS.SubDirs(path, "*", opts.mode)) do
		if opts.apply_folders then
			f(dir)
		end
		Recurse(dir, f, opts)
	end
end

local function Track(paths)
	for _, path in ipairs(paths) do
		-- path = path:lower()
		Spring.Log(LOG_SECTION, LOG.NOTICE, 'Watching: ' .. tostring(path))
		WG.Connector.Send("WatchFile", {
			path = path
		})
	end
end

-- unless anyFile is specified, only Lua files will be tracked
local function TrackVFSDir(vfsDir, anyFile)
	-- track only the relevant Lua context dirs, e.g. "LuaUI" or "LuaRules"
	local paths = {}
	Recurse(vfsDir,
		function(vfsFilePath)
			vfsFilePath = vfsFilePath:lower()
			local absPath = VFS.GetFileAbsolutePath(vfsFilePath)
			if  absPath == nil then
				return
			end
			local archiveName = VFS.GetArchiveContainingFile(vfsFilePath)
			if archiveName == (Game.gameName .. " " .. Game.gameVersion) then
				if not anyFile and vfsFilePath:sub(-4) == '.lua' then
					table.insert(paths, absPath)
					absPathToVfsPath[absPath] = vfsFilePath
				end
			end
		end, {
			mode = VFS.ZIP
		}
	)
	Track(paths)
end

function widget:Update()
	if lastChange == nil then
		return
	end

	if os.clock() - lastChange > WAIT_TIME then
		FlushChanges()
	end
end

-- TODO: Maybe we should send a list of paths instead
-- This could allow listeners to optimize reload
-- (e.g. only reload once per a list of files)
function FlushChanges()
	-- Cleanup early in case an error happens (prevents error spam)
	local buffer = fileChangedBuffer
	lastChange = nil
	fileChangedBuffer = {}

	local pathsMap = {}
	for _, cmd in pairs(buffer) do
		local path = cmd.path
		if not pathsMap[path] then
			pathsMap[path] = true
			OnFileChanged(path)
		end
	end
end

function widget:Initialize()
	if not WG.Connector or not WG.Connector.enabled then
		Spring.Log(LOG_SECTION, LOG.NOTICE, "Disabling springmon as the connector is also disabled.")
		widgetHandler:RemoveWidget(self)
		return
	end
	local addonPathToName = LoadAddonList()
	for vfsFilePath, _ in pairs(addonPathToName) do
		fileContextMap[vfsFilePath] = {
			widget = true
		}
	end
	-------------------------------------------------------
	-- Notice: widget is loaded as handler = true,
	-- So we need to pass the widget as a first argument
	-- Careful with changing this code or the widget loader
	-------------------------------------------------------
	widgetHandler:RegisterGlobal(widget, COMM_EVENTS.REGISTER_GADGET, function(vfsFilePath)
		local luaContexts = fileContextMap[vfsFilePath]
		if not luaContexts then
			luaContexts = {}
			fileContextMap[vfsFilePath] = luaContexts
		end
		luaContexts["gadget"] = true
	end)
	WG.Connector.Register("FileChanged", function(cmd)
		lastChange = os.clock()
		table.insert(fileChangedBuffer, cmd)
	end)

	Spring.Log(LOG_SECTION, LOG.NOTICE, "Watching files for changes...")
	TrackVFSDir("LuaUI")
	TrackVFSDir("LuaRules")

	Spring.SendLuaRulesMsg(COMM_EVENTS.SYNC_GADGETS)
end

local Springmon = {
	trackers = {},
	-- VFS -> tracker name mapping
	custom_trackers = {},
	-- TrackVFSDir = TrackVFSDir
}

function OnFileChanged(filePath)
	local tracker_name = Springmon.custom_trackers[filePath]
	if tracker_name ~= nil then
		local tracker = Springmon.trackers[custom_tracker]
		tracker.callback(filePath)
		return
	end

	for _, tracker in pairs(Springmon.trackers) do
		if tracker.canTrack ~= nil and tracker.canTrack(filePath) then
			tracker.callback(filePath)
			return
		end
	end

	local vfsPath = absPathToVfsPath[filePath]
	if not vfsPath then
		Spring.Log(LOG_SECTION, LOG.WARNING,
			"Cannot resolve VFS path for tracked file " ..
			tostring(filePath))
		return
	end
	local luaContexts = fileContextMap[vfsPath]
	if luaContexts == nil then
		Spring.Log(LOG_SECTION, LOG.WARNING,
			"Cannot reload " .. tostring(vfsPath) ..
			" : no detected Lua context. Reload manually.")
		return
	end
	for luaContext, _ in pairs(luaContexts) do
		if luaContext == "widget" then
			ReloadFile(vfsPath)
		else
			Spring.SendLuaRulesMsg(COMM_EVENTS.FILE_CHANGED .. vfsPath)
		end
	end
end

function Springmon.AddTracker(name, absPaths, callback, canTrack)
	if type(absPaths) == "string" then
		absPaths = {absPaths}
	end
	Springmon.trackers[name] = {
		absPaths = absPaths,
		callback = callback,
		canTrack = canTrack
	}
	Track(absPaths)
	for _, absPath in ipairs(absPaths) do
		Springmon.custom_trackers[absPath] = name
	end
end

function Springmon.RemoveTracker(name)
	local tracker = Springmon.trackers[name]
	if not tracker then
		Spring.Log(LOG_SECTION, LOG.WARNING,
			"Trying to remove tracker that doesn't exist: " .. tostring(name))
		return
	end

	for _, absPath in ipairs(tracker.absPaths) do
		Springmon.custom_trackers[absPath] = nil
	end
end

WG.Springmon = Springmon