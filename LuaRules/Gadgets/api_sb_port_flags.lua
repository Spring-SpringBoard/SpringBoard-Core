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
-- The three UI implementations are independent: exactly one builds a UI.
-- `sb_ui` names it; `useRml` stays for the RmlUi-vs-Chili checks that predate it.
function gadget:Initialize()
	local config = LoadPortFlags()
	local ui = config.ui
	if ui ~= "rmlui" and ui ~= "rust" then
		ui = "chili"
	end
	Spring.SetGameRulesParam("sb_ui", ui)
	Spring.SetGameRulesParam("useRml", (ui == "rmlui") and "true" or "false")
end
