----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Copy this file to both the luaui/widgets and the luarules/gadgets folders

-- Set this line to the Chonsole installation folder
CHONSOLE_FOLDER = "libs_sb/chonsole"

-- Present so the widget handler accepts this loader even when it bails early
-- (the Rust chonsole is active); the real Chonsole include redefines it.
function widget:GetInfo()
	return {
		name = "Chonsole Loader",
		desc = "Loads the Lua Chonsole unless the Rust chonsole is active",
		author = "SpringBoard",
		layer = 0,
		enabled = true,
	}
end

local function UseRustChonsole()
	local flags = VFS.LoadFile("port_flags.json", VFS.DEF_MODE)
	if not flags then
		return false
	end
	if not json then
		VFS.Include("libs_sb/json.lua", nil, VFS.ZIP)
	end
	local ok, config = pcall(json.decode, flags)
	return ok and config and config.chonsole == "rust"
end

if UseRustChonsole() then
	return
end

-- Do NOT modify the following lines
if Script.GetName() == "LuaUI" then
	VFS.Include(CHONSOLE_FOLDER .. "/luaui/widgets/ui_chonsole.lua", nil, VFS.DEF_MODE)
elseif Script.GetName() == "LuaRules" then
	VFS.Include(CHONSOLE_FOLDER .. "/luarules/gadgets/ui_chonsole.lua", nil, VFS.DEF_MODE)
end
