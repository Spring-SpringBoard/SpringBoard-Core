SaveAsAction = AbstractAction:extends{}

function SaveAsAction:execute()
    local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
    sfd = SaveProjectDialog(dir)
    sfd:setConfirmDialogCallback(
        function(path)
            Log.Notice("Saving project: " .. path .. " ...")
            local setProjectDirCommand = SetProjectDirCommand(path)
            -- set the project dir in both the synced and unsynced (TODO: needs to be fixed for cooperative editing)
            SCEN_EDIT.commandManager:execute(setProjectDirCommand)
            SCEN_EDIT.commandManager:execute(setProjectDirCommand, true)
            self:CreateProjectStructure(path)
            
            local saveCommand = SaveCommand(path)
            SCEN_EDIT.commandManager:execute(saveCommand, true)
            Log.Notice("Saved project.")
        end
    )
end

function SaveAsAction:CreateProjectStructure(projectDir)	
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
