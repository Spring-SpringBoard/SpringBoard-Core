----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Copy this file to the luaui/widgets folder

-- Set this line to the spring-wrapper-connection installation folder
SPRING_WRAPPER_CONNECTOR_DIR = "libs_sb/spring-wrapper-connector/"
JSON_LIB_PATH = "libs_sb/json.lua"

-- Do NOT modify the following lines
function widget:GetInfo()
	return {
		name      = "spring-wrapper-connector",
		desc      = "Spring wrapper connection provider",
		author    = "gajop",
		license   = "MIT",
		layer     = -10010,
		enabled   = true,
		handler   = true,
		api       = true,
		hidden    = true,
	}
end

if Script.GetName() == "LuaUI" then
	VFS.Include(SPRING_WRAPPER_CONNECTOR_DIR .. "luaui/widgets/api_connector.lua", nil, VFS.DEF_MODE)
end
