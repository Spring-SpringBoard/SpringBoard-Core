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
							local saveCommand = SaveCommand(path)
							success, errMsg = pcall(function()
								SCEN_EDIT.commandManager:execute(saveCommand, true)
							end)
							if not success then
								Spring.Echo(errMsg)
							end
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
							Spring.Echo("123")
							VFS.MapArchive(path)
							Spring.Echo("1234")
							local data = VFS.LoadFile("model.lua", VFS.ZIP)
							cmd = LoadCommand(data)
							SCEN_EDIT.commandManager:execute(cmd)

							local data = VFS.LoadFile("heightmap.data", VFS.ZIP)
							loadMap = LoadMap(data)
							SCEN_EDIT.commandManager:execute(loadMap)
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
					file = SCEN_EDIT_IMG_DIR .. "document-open.png", 
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