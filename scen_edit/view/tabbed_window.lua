TabbedWindow = LCS.class{}

function TabbedWindow:init()

	local generalPanel = LayoutPanel:New {
		x = 0,
		y = 0,
		width = "100%",
		height = "100%",
		children = {
			Button:New {
				height = SCEN_EDIT.conf.B_HEIGHT + 20,
				width = SCEN_EDIT.conf.B_HEIGHT + 20,
				caption = '',
				tooltip = "Save scenario", 
				OnClick = {
					function() 
						local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
						sfd = SaveFileDialog(dir)
						sfd:setConfirmDialogCallback(function(path)
							local saveCommand = SaveCommand(path)
							success, errMsg = pcall(function()
								SCEN_EDIT.commandManager:execute(saveCommand, true)
							end)
							if not success then
								Spring.Echo(errMsg)
							end
						end)
					end
				},
				children = {
					Image:New { 
						file=SCEN_EDIT_IMG_DIR .. "document-save.png", 
						height = SCEN_EDIT.conf.B_HEIGHT - 2, 
						width = SCEN_EDIT.conf.B_HEIGHT - 2, 
						margin = {0, 0, 0, 0},
					},
				},
			},
			Button:New {
				height = SCEN_EDIT.conf.B_HEIGHT + 20,
				width = SCEN_EDIT.conf.B_HEIGHT + 20,
				caption = '',
				tooltip = "Load scenario", 
				OnClick = {
					function()
						local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
						ofd = OpenFileDialog(dir)
						ofd:setConfirmDialogCallback(
						function(path)
							VFS.MapArchive(path)
							local data = VFS.LoadFile("model.lua", VFS.ZIP)
							cmd = LoadCommand(data)
							SCEN_EDIT.commandManager:execute(cmd)

							local data = VFS.LoadFile("heightmap.data", VFS.ZIP)
							loadMap = LoadMap(data)
							SCEN_EDIT.commandManager:execute(loadMap)
						end)
					end
				},
				children = {
					Image:New { 
						file = SCEN_EDIT_IMG_DIR .. "document-open.png", 
						height = SCEN_EDIT.conf.B_HEIGHT - 2, 
						width = SCEN_EDIT.conf.B_HEIGHT - 2, 
						margin = {0, 0, 0, 0},
					},
				},
			},
		}
	}

	self.window = Window:New {
		x = 500, 
		y = 300,
		width = 500,
		height = 500,
		parent = screen0,
		caption = "Scenario Toolbox v2",
		resizable = false,
		children = {
			Chili.TabPanel:New{
				x = 0, 
				right = 0,
				y = 20, 
				bottom = 10,
				minItemWidth = 100,
				tabs = {
					{ name = "general", children = {generalPanel} },
					{ name = "units", children = {} },
					{ name = "terrain", children = {} },
					{ name = "triggers", children = {} },
				},
			},
		}
	}
end

