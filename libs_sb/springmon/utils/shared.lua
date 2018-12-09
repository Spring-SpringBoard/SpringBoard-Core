COMM_EVENTS = {
	SYNC_GADGETS = "springmon_sync_gadgets",
	FILE_CHANGED = "springmon_file_changed",
	REGISTER_GADGET = "springmon_register_gadget"
}

function GetEvent(msg)
	for _, eventKey in pairs(COMM_EVENTS) do
		if msg:sub(1, #eventKey) == eventKey then
			return eventKey
		end
	end
end

LOG_SECTION = "springmon"

local luaContextName = Script.GetName()

-- addon VFS relative path -> addon name
local addonPathToName = {}

function GetAddonPathToName()
	return addonPathToName
end

local function GenerateAddonPathToNameMap(addonList)
	for name, addon in pairs(addonList) do
		-- Spring.Echo(addon)
		-- for k, v in pairs(addon) do
		--     Spring.Echo(k, v)
		-- end
		local vfsFilePath = (addon.filename or addon.filepath):lower()
		addonPathToName[vfsFilePath] = name
		-- local absPath = VFS.GetFileAbsolutePath(vfsFilePath)
		-- local archiveName = VFS.GetArchiveContainingFile(vfsFilePath)
		-- if archiveName == Game.gameName then
		--     addonPathToName[absPath] = name
		-- end
	end
	return addonPathToName
end

function LoadAddonList()
	local addonList
	if luaContextName == "LuaUI" then
		addonList = widgetHandler.knownWidgets
	elseif luaContextName == "LuaRules" then
		addonList = gadgetHandler.knownGadgets
	end
	return GenerateAddonPathToNameMap(addonList)
end

function ReloadFile(path)
	local addonName = addonPathToName[path]
	if not addonName then
		Spring.Log(LOG_SECTION, LOG.WARNING,
		"[" .. Script.GetName() .. "]" ..
		" No addon found for file: " .. tostring(path) ..
		". Reload manually")
		return
	end
	Spring.Log(LOG_SECTION, LOG.NOTICE,	"Reloading addon: " .. tostring(addonName) .. "...")
	if luaContextName == "LuaUI" then
		if widgetHandler:DisableWidget(addonName) then
			widgetHandler:EnableWidget(addonName)
		else
			widgetHandler:LoadWidget(path)
		end
	elseif luaContextName == "LuaRules" then
		if gadgetHandler:DisableGadget(addonName) then
			gadgetHandler:EnableGadget(addonName)
		else
			gadgetHandler:EnableGadget(path)
		end
	end
end