assert(RmlUi, "RmlUi is required for gui_rmlui_for_each_demo")

function widget:GetInfo()
	return {
		name = "RmlUi For-Each Demo",
		desc = "Shows data-for iteration over a Lua table using RmlUi.",
		author = "ChatGPT",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 999998,
		enabled = false
	}
end

local context
local document
local dm_handle
local MODEL_NAME = "rmlui_for_each_demo"

local function buildModel()
	return {
		dataBindingExamples = {
			availableThemes = {
				{ id = "base", name = "Base" },
				{ id = "armada", name = "Armada" },
				{ id = "cortex", name = "Cortex" },
				{ id = "legion", name = "Legion" },
			},
		},
		notes = {
			"These rows come from a Lua table.",
			"RmlUi loops with data-for.",
			"Only reading values; no two-way binding.",
		},
	}
end

function widget:Initialize()
	if Spring.GetGameRulesParam("useRml") ~= "true" then
		widgetHandler:RemoveWidget(self)
		return
	end
	-- Use the shared context; fail immediately if missing
	context = RmlUi.GetContext("shared")
	assert(context, "[RmlUiForEachDemo] Shared context not available")

	-- Remove any stale model before re-opening
	context:RemoveDataModel(MODEL_NAME)

	dm_handle = assert(context:OpenDataModel(MODEL_NAME, buildModel()), "[RmlUiForEachDemo] Failed to open data model")

	document = assert(context:LoadDocument("LuaUI/rmlui/rmlui_for_each_demo.rml", widget), "[RmlUiForEachDemo] Failed to load document")
	document:ReloadStyleSheet()
	context:EnableMouseCursor(true)

	document:Show()
	context:Update()
	return true
end

function widget:Shutdown()
	if document then
		document:Close()
		document = nil
	end
	if context and dm_handle then
		context:RemoveDataModel(MODEL_NAME)
	end
	dm_handle = nil
	context = nil
end

function widget:Update()
	if context then
		context:Update()
	end
end

function widget:DrawScreen()
	if context then
		context:Render()
	end
end
