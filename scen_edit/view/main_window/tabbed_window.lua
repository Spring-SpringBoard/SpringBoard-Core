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
		height = 220,
		parent = screen0,
		caption = "Scenario Toolbox v2",
		resizable = false,
		padding = {5, 0, 0, 0},
		children = {
			Chili.TabPanel:New {
				x = 0, 
				right = 0,
				y = 30, 
				bottom = 20,
				padding = {0, 0, 0, 0},
				tabs = {
					{ name = "general", children = {generalPanel:getControl()} },
					{ name = "unit", children = {unitFeaturePanel:getControl()} },
					{ name = "terrain", children = {terrainPanel:getControl()} },
					{ name = "trigger", children = {triggerPanel:getControl()} },
				},
			},
			Button:New {
				x = 10,
				bottom = 10,
				height = 40,
				width = 40,
				caption = '',
				tooltip = "Undo", 
				OnClick = {
					function() 
						local undoCommand = UndoCommand()
						SCEN_EDIT.commandManager:execute(undoCommand)
					end
				},
				children = {
					Image:New { 
						file=SCEN_EDIT_IMG_DIR .. "undo.png", 
						height = 20, 
						width = 20,
						margin = {0, 0, 0, 0},
						x = 0,
					},
				},
			},
			Button:New {
				x = 50,
				bottom = 10,
				height = 40,
				width = 40,
				caption = '',
				tooltip = "Redo", 
				OnClick = {
					function() 
						local redoCommand = RedoCommand()
						SCEN_EDIT.commandManager:execute(redoCommand)
					end
				},
				children = {
					Image:New { 
						file=SCEN_EDIT_IMG_DIR .. "redo.png", 
						height = 20, 
						width = 20,
						margin = {0, 0, 0, 0},
						x = 0,
					},
				},
			},
			Button:New {
				x = 90,
				bottom = 10,
				height = 40,
				width = 40,
				caption = '',
				tooltip = "Reload meta model", 
				OnClick = {
					function() 
						local reloadMetaModelCommand = ReloadMetaModelCommand()
						SCEN_EDIT.commandManager:execute(reloadMetaModelCommand)
					end
				},
				children = {
					Image:New { 
						file=SCEN_EDIT_IMG_DIR .. "refresh.png", 
						height = 20, 
						width = 20,
						margin = {0, 0, 0, 0},
						x = 0,
					},
				},
			}
		}
	}
end

