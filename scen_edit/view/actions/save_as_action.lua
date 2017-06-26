SaveAsAction = AbstractAction:extends{}

function SaveAsAction:execute()
    sfd = SaveProjectDialog(SB_PROJECTS_DIR)
    sfd:setConfirmDialogCallback(
        function(path)
            Log.Notice("Saving project: " .. path .. " ...")
            local setProjectDirCommand = SetProjectDirCommand(path)
            -- set the project dir in both the synced and unsynced (TODO: needs to be fixed for cooperative editing)
            SB.commandManager:execute(setProjectDirCommand)
            SB.commandManager:execute(setProjectDirCommand, true)
            self:CreateProjectStructure(path)

            self:Save(path)
        end
    )
end

function SaveAsAction:Save(path)
    local saveCommand = SaveCommand(path)
    SB.commandManager:execute(saveCommand, true)
    Log.Notice("Saved project.")
end

function SaveAsAction:CreateProjectStructure(projectDir)
	-- create project if it doesn't exist already
	if SB.DirExists(projectDir, VFS.RAW_ONLY) then
        return
    end

	Spring.CreateDir(projectDir)
	Spring.CreateDir(Path.Join(projectDir, "triggers"))

	local myCustomTriggersLua = [[
return {
    dataTypes = {
        -- Custom data types go here
    },
    events = {
        -- Custom events go here
    },
	actions = {
		-- Custom actions go here
	},
	functions = {
		-- Custom functions go here
	},
}

]]
	local file = assert(io.open(Path.Join(projectDir, "triggers/my_custom_triggers.lua"), "w"))
	file:write(myCustomTriggersLua)
	file:close()
end
