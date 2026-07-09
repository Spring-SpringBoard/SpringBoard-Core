function gadget:GetInfo()
	return {
		name      = "Port Flags (SB)",
		desc      = "Exposes port_flags.json values as game rules params (e.g. ui mode).",
		author    = "gajop",
		date      = "2026",
		license   = "GNU GPL v2",
		layer     = -10000,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local function LoadPortFlags()
	local raw = VFS.LoadFile("port_flags.json", VFS.DEF_MODE)
	if not raw or raw == "" then
		return {}
	end
	if not json then
		VFS.Include("libs_sb/json.lua", nil, VFS.ZIP)
	end
	local ok, config = pcall(json.decode, raw)
	if not ok or type(config) ~= "table" then
		return {}
	end
	return config
end

-- Must run in Initialize, not GamePreload: SB's view.lua and the RmlUi/Chili
-- widgets read this param during LuaUI load, which happens before GamePreload.
function gadget:Initialize()
	local config = LoadPortFlags()
	Spring.SetGameRulesParam("useRml", (config.ui == "rmlui") and "true" or "false")
end
