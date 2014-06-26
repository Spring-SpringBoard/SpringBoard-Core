GeneralPanel = AbstractMainWindowPanel:extends{}

function GeneralPanel:init()
	self:super("init")
	self.control:AddChild(TabbedPanelButton({			
			tooltip = "Save project", 
			OnClick = {
				function() 
					if SCEN_EDIT.model:GetProjectDir() == nil then
						local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
						sfd = SaveProjectDialog(dir)
						sfd:setConfirmDialogCallback(
							function(path)
								Spring.Echo("Saving project: " .. path .. " ...")
								local setProjectDirCommand = SetProjectDirCommand(path)
								-- set the project dir in both the synced and unsynced (TODO: needs to be fixed for cooperative editing)
								SCEN_EDIT.commandManager:execute(setProjectDirCommand)
								SCEN_EDIT.commandManager:execute(setProjectDirCommand, true)
								self:CreateProjectStructure()
								
								local saveCommand = SaveCommand(path)
								SCEN_EDIT.commandManager:execute(saveCommand, true)
								Spring.Echo("Saved project.")
							end
						)
					else
						local path = SCEN_EDIT.model:GetProjectDir()
						Spring.Echo("Saving project: " .. path .. " ...")
						local saveCommand = SaveCommand(path)
						SCEN_EDIT.commandManager:execute(saveCommand, true)
						Spring.Echo("Saved project.")
					end
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "document-save.png" }),
				TabbedPanelLabel({ caption = "Save" }),
			},
		})
	)
	self.control:AddChild(TabbedPanelButton({			
			tooltip = "Save project as...", 
			OnClick = {
				function() 
					local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
					sfd = SaveProjectDialog(dir)
					sfd:setConfirmDialogCallback(
						function(path)
							Spring.Echo("Saving project: " .. path .. " ...")
							local setProjectDirCommand = SetProjectDirCommand(path)
							-- set the project dir in both the synced and unsynced (TODO: needs to be fixed for cooperative editing)
							SCEN_EDIT.commandManager:execute(setProjectDirCommand)
							SCEN_EDIT.commandManager:execute(setProjectDirCommand, true)
							self:CreateProjectStructure()
							
							local saveCommand = SaveCommand(path)
                            SCEN_EDIT.commandManager:execute(saveCommand, true)
							Spring.Echo("Saved project.")
						end
					)
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "document-save.png" }),
				TabbedPanelLabel({ caption = "Save as" }),
			},
		})
	)	
	self.control:AddChild(TabbedPanelButton({			
			tooltip = "Load project", 
			OnClick = {
				function()
					local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
					ofd = OpenFileDialog(dir)					
					ofd:setConfirmDialogCallback(
						function(path)
                            local cmd = LoadCommandWidget(path)
                            SCEN_EDIT.commandManager:execute(cmd, true)
						end
					)
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "document-open.png" }),
				TabbedPanelLabel({ caption = "Load" }),
			},		
		})
	)
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Scenario info settings", 
			OnClick = {
				function()
					local scenarioInfoView = ScenarioInfoView()
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "info.png" }),
				TabbedPanelLabel({ caption = "Info" }),
			},		
		})
	)
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Export to archive", 
			OnClick = {
				function() 
					if SCEN_EDIT.model:GetProjectDir() ~= nil then
						local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
						sfd = ExportFileDialog(dir)
						sfd:setConfirmDialogCallback(
							function(path)
								Spring.Echo("Exporting archive: " .. path .. " ...")
								local exportCommand = ExportCommand(path)
								SCEN_EDIT.commandManager:execute(exportCommand, true)
								Spring.Echo("Exported archive.")
							end
						)
					else
						Spring.Echo("The project must be saved before exporting")
					end
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "document-save.png" }),
				TabbedPanelLabel({ caption = "Export" }),
			},
		})
	)
end

function GeneralPanel:CreateProjectStructure(projectDir)	
	-- create project if it doesn't exist already
	if not SCEN_EDIT.DirExists(projectDir, VFS.RAW_ONLY) then
		Spring.CreateDir(projectDir)
		Spring.CreateDir(projectDir .. "/triggers")

		local myCustomTriggersLua = [[
return {
	actions = {
		-- My custom actions go here
	},
	functions = {
		-- My custom functions go here
	},
}

]]
		local file = assert(io.open(projectDir .. "/triggers/my_custom_triggers.lua", "w"))
		file:write(myCustomTriggersLua)
		file:close()
	end
end
