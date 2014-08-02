SCEN_EDIT.Include(SCEN_EDIT_VIEW_ACTIONS_DIR .. "save_as_action.lua")
SaveAction = SaveAsAction:extends{}

function SaveAction:execute()
    if SCEN_EDIT.projectDir == nil then
        self:super("execute")
    else
        local path = SCEN_EDIT.projectDir
        Spring.Echo("Saving project: " .. path .. " ...")
        local saveCommand = SaveCommand(path)
        SCEN_EDIT.commandManager:execute(saveCommand, true)
        Spring.Echo("Saved project.")
    end
end
