TabbedWindow = LCS.class{}

function TabbedWindow:init()
	local unitFeaturePanel = UnitFeaturePanel()
	local terrainPanel = TerrainPanel()
	local envPanel = EnvPanel()
	local metaPanel = MetaPanel()
    local generalPanel = GeneralPanel()
	local shaderPanel = ShaderPanel()

	local mainPanelY = 130
	local commonControls = {
		Button:New {
			x = 10,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Reload meta model",
			OnClick = {
				function()
					SB.conf:initializeListOfMetaModelFiles()
					local reloadMetaModelCommand = ReloadMetaModelCommand(SB.conf:GetMetaModelFiles())
					SB.commandManager:execute(reloadMetaModelCommand)
					SB.commandManager:execute(reloadMetaModelCommand, true)
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "recycle.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
		Button:New {
			x = 50,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Copy (Ctrl+C)",
			OnClick = {
				function()
					local selType, items = SB.view.selectionManager:GetSelection()
					if selType == "units" then
						SB.clipboard:CopyUnits(items)
						return true
					elseif selType == "features" then
						SB.clipboard:CopyFeatures(items)
						return true
					end
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "copy.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
		Button:New {
			x = 90,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Cut (Ctrl+X)",
			OnClick = {
				function()
					local selType, items = SB.view.selectionManager:GetSelection()
					if selType == "units" then
						SB.clipboard:CutUnits(items)
						return true
					elseif selType == "features" then
						SB.clipboard:CutFeatures(items)
						return true
					end
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "scissors-rotated.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
		Button:New {
			x = 130,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Paste (Ctrl+V)",
			OnClick = {
				function()
					local x, y = Spring.GetMouseState()
					local result, coords = Spring.TraceScreenRay(x, y, true)
					if result == "ground" then
						SB.clipboard:Paste(coords)
						return true
					end
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "stabbed-note.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
		Button:New {
			x = 170,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Save project (Ctrl+S)",
			OnClick = {
				function()
					SaveAction():execute()
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "save.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
		Button:New {
			x =  210,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Save project as... (Ctrl+Shift+S)",
			OnClick = {
				function()
					SaveAsAction():execute()
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "save.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
		Button:New {
			x = 250,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Load project (Ctrl-O)",
			OnClick = {
				function()
					LoadAction():execute()
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "open-folder.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
		Button:New {
			x = 290,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Export to (Ctrl-E)...",
			OnClick = {
				function()
					ExportAction():execute()
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "save.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
		Button:New {
			x = 330,
			y = mainPanelY,
			height = 40,
			width = 40,
			caption = '',
			tooltip = "Import from (Ctrl-I)...",
			OnClick = {
				function()
					ImportAction():execute()
				end
			},
			children = {
				Image:New {
					file = SB_IMG_DIR .. "open-folder.png",
					height = 20,
					width = 20,
					margin = {0, 0, 0, 0},
					x = 0,
				},
			},
		},
	}

	local controls = {}
	if SB.conf.SHOW_BASIC_CONTROLS then
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
			{ name = "Object", children = {unitFeaturePanel:getControl()} },
			{ name = "Map", children = {terrainPanel:getControl()} },
			{ name = "Env", children = {envPanel:getControl()} },
			{ name = "Trigger", children = {metaPanel:getControl()} },
			{ name = "General", children = {generalPanel:getControl()} },
			-- { name = "Shaders", children = {shaderPanel:getControl()} },
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
		--height = 110 + SB.conf.TOOLBOX_ITEM_HEIGHT,
		height = "100%",
		parent = screen0,
		caption = "",
		resizable = false,
		draggable = false,
		padding = {5, 0, 0, 0},
		children = controls,
	}
end
