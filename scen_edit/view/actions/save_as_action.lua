SB.Include(SB_VIEW_ACTIONS_DIR .. "action.lua")

SaveProjectAsAction = Action:extends{}

SaveProjectAsAction:Register({
    name = "sb_save_project_as",
    tooltip = "Save project as...",
    image = SB_IMG_DIR .. "save.png",
    toolbar_order = 5,
    hotkey = {
        key = KEYSYMS.S,
        ctrl = true,
        shift = true,
    },
})

function SaveProjectAsAction:canExecute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot save while testing.")
        return false
    end
    return true
end

function SaveProjectAsAction:execute()
    local origProjDir = SB.projectDir
    local sfd = SaveProjectDialog(SB_PROJECTS_DIR)
    sfd:setConfirmDialogCallback(
        function(path)
            local isNewProject = path ~= origProjDir
            if isNewProject then
                Log.Notice("Saving (new) project: " .. path .. " ...")
            else
                Log.Notice("Saving project: " .. path .. " ...")
            end
            local setProjectDirCommand = SetProjectDirCommand(path)
            -- set the project dir in both the synced and unsynced (TODO: needs to be fixed for cooperative editing)
            SB.commandManager:execute(setProjectDirCommand)
            SB.commandManager:execute(setProjectDirCommand, true)
            self:CreateProjectStructure(path)

            self:Save(path, isNewProject)

            return true
        end
    )
end

function SaveProjectAsAction:Save(path, isNewProject)
    local saveCommand = SaveCommand(path, isNewProject)
    SB.commandManager:execute(saveCommand, true)

    -- We delay this notice twice to ensure texture map and screenshot is taken
    SB.delayGL(function()
        SB.delayGL(function()
            Log.Notice("Saved project.")
        end)
    end)
end

function SaveProjectAsAction:CreateProjectStructure(projectDir)
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

