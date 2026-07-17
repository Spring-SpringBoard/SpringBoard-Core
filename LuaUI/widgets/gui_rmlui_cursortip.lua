function widget:GetInfo()
	return {
		name    = "Cursor Tooltip (RmlUi)",
		desc    = "Shows unit/feature info under the cursor. RmlUi replacement for the Chili cursortip.",
		author  = "gajop",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

local RML_CONTEXT_NAME  = "shared"
local RML_DOCUMENT_PATH = "LuaUI/rmlui/cursortip.html"

local CURSOR_OFFSET_X = 18
local CURSOR_OFFSET_Y = 18

local tipData = {
	title = "",
	rows = {},
}

local rml = { context = nil, document = nil, dataModel = nil, tip = nil }

local lastKey
local shown = false

local function Initialized()
	return rml.document ~= nil
end

local function LoadDocument()
	if type(RmlUi) ~= "table" then
		return false
	end

	local context = RmlUi.GetContext(RML_CONTEXT_NAME)
	if not context then
		return false
	end

	rml.dataModel = context:OpenDataModel("cursortip", tipData)
	if not rml.dataModel then
		return false
	end

	local document = context:LoadDocument(RML_DOCUMENT_PATH, widget)
	if not document then
		return false
	end

	document:ReloadStyleSheet()
	document:Show()

	rml.context = context
	rml.document = document
	rml.tip = document:GetElementById("cursortip")
	return rml.tip ~= nil
end

-- The engine's own tooltip string is unusable here ("No tooltip defined" for
-- most editor objects), so build the tip from what the ray actually hit.
local function DescribeUnit(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitDef = unitDefID and UnitDefs[unitDefID]
	if not unitDef then
		return nil
	end

	local rows = {}
	rows[#rows + 1] = { text = unitDef.name }

	local health, maxHealth = Spring.GetUnitHealth(unitID)
	if health and maxHealth and maxHealth > 0 then
		rows[#rows + 1] = { text = string.format("Health: %d / %d", math.floor(health), math.floor(maxHealth)) }
	end

	local teamID = Spring.GetUnitTeam(unitID)
	if teamID then
		rows[#rows + 1] = { text = "Team: " .. tostring(teamID) }
	end

	return unitDef.humanName or unitDef.name, rows, "u" .. unitID
end

local function DescribeFeature(featureID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	local featureDef = featureDefID and FeatureDefs[featureDefID]
	if not featureDef then
		return nil
	end

	local rows = { { text = featureDef.name } }

	local health, maxHealth = Spring.GetFeatureHealth(featureID)
	if health and maxHealth and maxHealth > 0 then
		rows[#rows + 1] = { text = string.format("Health: %d / %d", math.floor(health), math.floor(maxHealth)) }
	end

	return featureDef.tooltip or featureDef.name, rows, "f" .. featureID
end

-- Pick radius in pixels around the cursor. A screen rectangle is used rather
-- than TraceScreenRay because the engine's GUI ray does not report SpringBoard's
-- features (its own tooltip reads "No tooltip defined" while hovering one).
local PICK_RADIUS = 16

local function PickObject(mx, my)
    local units = Spring.GetUnitsInScreenRectangle(
        mx - PICK_RADIUS, my - PICK_RADIUS, mx + PICK_RADIUS, my + PICK_RADIUS)
    if units and units[1] then
        return "unit", units[1]
    end

    local features = Spring.GetFeaturesInScreenRectangle(
        mx - PICK_RADIUS, my - PICK_RADIUS, mx + PICK_RADIUS, my + PICK_RADIUS)
    if features and features[1] then
        return "feature", features[1]
    end
end

local function CurrentTip()
	local mx, my, lmb = Spring.GetMouseState()
	if lmb then
		return nil
	end

	if WG.SB and WG.SB.view and WG.SB.view.IsPointInsideUI and WG.SB.view:IsPointInsideUI(mx, my) then
		return nil
	end

	local kind, id = PickObject(mx, my)
	if kind == "unit" then
		local title, rows, key = DescribeUnit(id)
		return title, rows, key, mx, my
	elseif kind == "feature" then
		local title, rows, key = DescribeFeature(id)
		return title, rows, key, mx, my
	end

	return nil
end

local function Hide()
	if not shown then
		return
	end
	shown = false
	lastKey = nil
	rml.tip:SetClass("hidden", true)
end

local function Show(title, rows, key, mx, my)
	if key ~= lastKey then
		lastKey = key
		rml.dataModel.title = title
		rml.dataModel.rows = rows
	end

	if not shown then
		shown = true
		rml.tip:SetClass("hidden", false)
	end

	local _, viewHeight = Spring.GetViewGeometry()
	rml.tip.style["left"] = (mx + CURSOR_OFFSET_X) .. "px"
	rml.tip.style["top"] = (viewHeight - my + CURSOR_OFFSET_Y) .. "px"
end

function widget:Initialize()
	-- The native UI owns its own cursor tip. `useRml` is false for Rust today,
	-- but keep this explicit so a stale compatibility flag cannot load both.
	if Spring.GetGameRulesParam("sb_ui") ~= "rmlui" then
		widgetHandler:RemoveWidget(widget)
		return
	end
	if Spring.GetGameRulesParam("useRml") ~= "true" then
		widgetHandler:RemoveWidget(widget)
		return
	end
	if Spring.GetGameRulesParam("sb_gameMode") == "play" then
		widgetHandler:RemoveWidget(widget)
		return
	end
	if not LoadDocument() then
		widgetHandler:RemoveWidget(widget)
		return
	end
	Spring.SetDrawSelectionInfo(false)
end

function widget:Shutdown()
	if rml.document then
		rml.document:Close()
		rml.document = nil
	end
	if rml.context and rml.dataModel then
		rml.context:RemoveDataModel("cursortip")
		rml.dataModel = nil
	end
end

function widget:Update()
	if not Initialized() then
		return
	end

	local title, rows, key, mx, my = CurrentTip()
	if not title then
		Hide()
		return
	end

	Show(title, rows, key, mx, my)
end
