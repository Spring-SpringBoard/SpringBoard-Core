TabbedWindow = LCS.class{}

function TabbedWindow:init()

	local generalPanel = GeneralPanel()
	local unitFeaturePanel = UnitFeaturePanel()
	local terrainPanel = TerrainPanel()
	local triggerPanel = TriggerPanel()

	self.window = Window:New {
		right = 0,
		y = 150,
		width = 300,
		height = 200,
		parent = screen0,
		caption = "Scenario Toolbox v2",
		resizable = false,
		padding = {5, 0, 0, 0},
		children = {
			Chili.TabPanel:New {
				x = 0, 
				right = 0,
				y = 30, 
				bottom = 0,
				padding = {0, 0, 0, 0},
				tabs = {
					{ name = "general", children = {generalPanel:getControl()} },
					{ name = "unit", children = {unitFeaturePanel:getControl()} },
					{ name = "terrain", children = {terrainPanel:getControl()} },
					{ name = "trigger", children = {triggerPanel:getControl()} },
				},
			},
		}
	}
end

