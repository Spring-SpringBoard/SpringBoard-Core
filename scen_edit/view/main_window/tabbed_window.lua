TabbedWindow = LCS.class{}

function TabbedWindow:init()
	local generalPanel = GeneralPanel()
	local unitFeaturePanel = UnitFeaturePanel()
	local terrainPanel = TerrainPanel()
	local metaPanel = MetaPanel()
    local alliancePanel = AlliancePanel()
	local shaderPanel = ShaderPanel()

	local commonControls = {
		Button:New {
			x = 10,
			y = 120,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Undo (Ctrl+Z)",
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
			y = 120,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Redo (Ctrl+R)",
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
			y = 120,
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
			y = 120,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Copy (Ctrl+C)",
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
			y = 120,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Cut (Ctrl+X)",
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
			y = 120,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Paste (Ctrl+V)",
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
		}
	}

	local controls = {}
	local mainPanelY = 130
	if SCEN_EDIT.conf.SHOW_BASIC_CONTROLS then
		controls = commonControls
		mainPanelY = mainPanelY + 45
	end
	table.insert(controls, Chili.TabPanel:New {
		x = 0,
		right = 0,
		y = 10,
		bottom = 20,
		padding = {0, 0, 0, 0},
		tabs = {
			{ name = "General", children = {generalPanel:getControl()} },
			{ name = "Unit", children = {unitFeaturePanel:getControl()} },
			{ name = "Map", children = {terrainPanel:getControl()} },
			{ name = "Trigger", children = {metaPanel:getControl()} },
			{ name = "Team", children = {alliancePanel:getControl()} },
		--	{ name = "Shaders", children = {shaderPanel:getControl()} },
		},
	})

	table.insert(controls, Chili.Line:New {
		y = mainPanelY - 5,
		x = 0,
		width = "100%",
	})

	self.mainPanel = Chili.Control:New {
		x = 0,
		width = "100%",
		y = mainPanelY,
		bottom = 5,
		padding = {0, 0, 0, 0},
	}
	table.insert(controls, self.mainPanel)

	self.window = Window:New {
		right = 0,
		y = 0,
		width = 500,
		--height = 110 + SCEN_EDIT.conf.TOOLBOX_ITEM_HEIGHT,
		height = "100%",
		parent = screen0,
		caption = "",
		resizable = false,
		draggable = false,
		padding = {5, 0, 0, 0},
		children = controls,
	}
end
