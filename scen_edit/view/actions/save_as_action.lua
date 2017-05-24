SaveAsAction = AbstractAction:extends{}

function SaveAsAction:execute()
    local dir = FilePanel.lastDir or SB_PROJECTS_DIR
    sfd = SaveProjectDialog(dir)
    sfd:setConfirmDialogCallback(
        function(path)
            Log.Notice("Saving project: " .. path .. " ...")
            local setProjectDirCommand = SetProjectDirCommand(path)
            -- set the project dir in both the synced and unsynced (TODO: needs to be fixed for cooperative editing)
            SB.commandManager:execute(setProjectDirCommand)
            SB.commandManager:execute(setProjectDirCommand, true)
            self:CreateProjectStructure(path)

            local saveCommand = SaveCommand(path)
            SB.commandManager:execute(saveCommand, true)
            Log.Notice("Saved project.")
        end
    )
end

function SaveAsAction:CreateProjectStructure(projectDir)
	-- create project if it doesn't exist already
	if not SB.DirExists(projectDir, VFS.RAW_ONLY) then
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
