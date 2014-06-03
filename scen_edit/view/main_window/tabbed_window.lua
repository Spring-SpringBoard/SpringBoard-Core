TabbedWindow = LCS.class{}

function TabbedWindow:init()

	local generalPanel = GeneralPanel()
	local unitFeaturePanel = UnitFeaturePanel()
	local terrainPanel = TerrainPanel()
	local metaPanel = MetaPanel()
    local alliancePanel = AlliancePanel()

	self.window = Window:New {
		right = 0,
		y = 150,
		width = 375,
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
					{ name = "General", children = {generalPanel:getControl()} },
					{ name = "Unit", children = {unitFeaturePanel:getControl()} },
					{ name = "Terrain", children = {terrainPanel:getControl()} },
					{ name = "Trigger", children = {metaPanel:getControl()} },
                    { name = "Alliance", children = {alliancePanel:getControl()} },
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
                        SCEN_EDIT.conf:initializeListOfMetaModelFiles()
						local reloadMetaModelCommand = ReloadMetaModelCommand(SCEN_EDIT.conf:GetMetaModelFiles())
						SCEN_EDIT.commandManager:execute(reloadMetaModelCommand)
						SCEN_EDIT.commandManager:execute(reloadMetaModelCommand, true)
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
			},
			Button:New {
				x = 130,
				bottom = 10,
				height = 40,
				width = 40,
				caption = '',
				tooltip = "Copy", 
				OnClick = {
					function() 
					    local selType, items = SCEN_EDIT.view.selectionManager:GetSelection()
						if selType == "units" then
							SCEN_EDIT.clipboard:CopyUnits(items)
							return true
						elseif selType == "features" then
							SCEN_EDIT.clipboard:CopyFeatures(items)
							return true
						end
					end
				},
				children = {
					Image:New { 
						file=SCEN_EDIT_IMG_DIR .. "copy.png", 
						height = 20, 
						width = 20,
						margin = {0, 0, 0, 0},
						x = 0,
					},
				},
			},
			Button:New {
				x = 170,
				bottom = 10,
				height = 40,
				width = 40,
				caption = '',
				tooltip = "Cut", 
				OnClick = {
					function() 
					    local selType, items = SCEN_EDIT.view.selectionManager:GetSelection()
						if selType == "units" then
							SCEN_EDIT.clipboard:CutUnits(items)
							return true
						elseif selType == "features" then
							SCEN_EDIT.clipboard:CutFeatures(items)
							return true
						end
					end
				},
				children = {
					Image:New { 
						file=SCEN_EDIT_IMG_DIR .. "cut.png", 
						height = 20, 
						width = 20,
						margin = {0, 0, 0, 0},
						x = 0,
					},
				},
			},
			Button:New {
				x = 210,
				bottom = 10,
				height = 40,
				width = 40,
				caption = '',
				tooltip = "Paste", 
				OnClick = {
					function() 
						local x, y = Spring.GetMouseState()
						local result, coords = Spring.TraceScreenRay(x, y, true)
						if result == "ground" then
							SCEN_EDIT.clipboard:Paste(coords)
							return true
						end
					end
				},
				children = {
					Image:New { 
						file=SCEN_EDIT_IMG_DIR .. "paste.png", 
						height = 20, 
						width = 20,
						margin = {0, 0, 0, 0},
						x = 0,
					},
				},
			},			
		}
	}
end

