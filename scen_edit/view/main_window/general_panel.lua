GeneralPanel = AbstractMainWindowPanel:extends{}

function GeneralPanel:init()
	self:super("init")
	self.control:AddChild(Button:New {
			height = 80,
			width = 80,
			caption = '',
			tooltip = "Save scenario", 
			OnClick = {
				function() 
					local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
					sfd = SaveFileDialog(dir)
					sfd:setConfirmDialogCallback(
						function(path)
							Spring.Echo("Saving archive: " .. path .. " ...")
							local saveCommand = SaveCommand(path)
                            SCEN_EDIT.commandManager:execute(saveCommand, true)
							Spring.Echo("Saved archive.")
						end
					)
				end
			},
			children = {
				Image:New { 
					file=SCEN_EDIT_IMG_DIR .. "document-save.png", 
					height = 40, 
					width = 40,
					margin = {0, 0, 0, 0},
					x = 10,
				},
				Label:New {
					caption = "Save",
					y = 40,
					x = 14,
				},
			},
		}
	)
	self.control:AddChild(Button:New {
			height = 80,
			width = 80,
			caption = '',
			tooltip = "Load scenario", 
			OnClick = {
				function()
					local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
					ofd = OpenFileDialog(dir)
					ofd:setConfirmDialogCallback(
						function(path)
                            local cmd = LoadCommandWidget(path, true)
                            SCEN_EDIT.commandManager:execute(cmd, true)
						end
					)
				end
			},
			children = {
				Image:New { 
					file = SCEN_EDIT_IMG_DIR .. "document-open.png", 
					height = 40, 
					width = 40,
					margin = {0, 0, 0, 0},
					x = 10,
				},
				Label:New {
					caption = "Load",
					y = 40,
					x = 14,
				},
			},		
		}
	)
	self.control:AddChild(Button:New {
			height = 80,
			width = 80,
			caption = '',
			tooltip = "Scenario info settings", 
			OnClick = {
				function()
					local scenarioInfoView = ScenarioInfoView()
				end
			},
			children = {
				Image:New { 
					file = SCEN_EDIT_IMG_DIR .. "info.png", 
					height = 40, 
					width = 40,
					margin = {0, 0, 0, 0},
					x = 10,
				},
				Label:New {
					caption = "Info",
					y = 40,
					x = 14,
				},
			},		
		}
	)
end
