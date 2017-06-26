SB.Include(SB_VIEW_ACTIONS_DIR .. "save_as_action.lua")
SaveAction = SaveAsAction:extends{}

function SaveAction:execute()
    if SB.projectDir == nil then
        self:super("execute")
    else
        local path = SB.projectDir
        Log.Notice("Saving project: " .. path .. " ...")
        self:Save(path)
    end
end
