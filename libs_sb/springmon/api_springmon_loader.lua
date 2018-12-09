----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Copy this file to the luaui/widgets and luarules/gadgets folders

-- Set this line to the springmon installation folder
SPRINGMON_DIR = "libs/springmon/"

-- Do NOT modify the following lines
local addon
if Script.GetName() == "LuaUI" then
	addon = widget
elseif Script.GetName() == "LuaRules" then
	addon = gadget
end
function addon:GetInfo()
	local getInfo = {
		name      = "springmon",
		desc      = "Spring file monitor and autoreloader",
		author    = "gajop",
		license   = "MIT",
		layer     = -999,
		enabled   = true,
		api       = true,
		hidden    = true,
		handler   = true,
	}
	-- gadget unsynced
	if gadgetHandler and not Script.GetSynced() then
		getInfo.handler = false
	end
	return getInfo
end

if Script.GetName() == "LuaUI" then
	VFS.Include(SPRINGMON_DIR .. "luaui/widgets/api_springmon.lua", nil, VFS.DEF_MODE)
elseif Script.GetName() == "LuaRules" then
	VFS.Include(SPRINGMON_DIR .. "luarules/gadgets/api_springmon.lua", nil, VFS.DEF_MODE)
end
