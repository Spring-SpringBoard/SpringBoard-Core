VFS.Include(SPRINGMON_DIR .. "utils/shared.lua")

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

local absPathToVfsPath = {}

local function TrackFiles()
	Spring.Log(LOG_SECTION, LOG.NOTICE, "Watching files for changes...")
	-- track only the relevant Lua context dirs, e.g. "LuaUI" or "LuaRules"
	for _, luaContextName in ipairs({"LuaUI", "LuaRules"}) do
		Recurse(luaContextName, function(vfsFilePath)
			vfsFilePath = vfsFilePath:lower()
			local absPath = VFS.GetFileAbsolutePath(vfsFilePath)
			local archiveName = VFS.GetArchiveContainingFile(vfsFilePath)
			if archiveName == (Game.gameName .. " " .. Game.gameVersion) then
				Spring.Log(LOG_SECTION, LOG.NOTICE, 'Watching: ' .. tostring(vfsFilePath))
				WG.Connector.Send("WatchFile", {
					path = absPath
				})
				absPathToVfsPath[absPath] = vfsFilePath
			end
		end, {
			mode = VFS.ZIP
		})
	end
end

-- vfsFilePath -> { context1 = true, context2 = true... }
-- where context is one of: "widget", "gadget_synced", "gadget_unsynced")
local fileContextMap = {}

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
	WG.Connector.Register("FileChanged", function(command)
		local vfsPath = absPathToVfsPath[command.path]
		if not vfsPath then
			Spring.Log(LOG_SECTION, LOG.WARNING,
			"Cannot resolve VFS path for tracked file " ..
			tostring(command.path))
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
	end)
	TrackFiles()
	Spring.SendLuaRulesMsg(COMM_EVENTS.SYNC_GADGETS)
end
