SB.Include(SB_VIEW_ACTIONS_DIR .. "save_as_action.lua")
SaveAction = SaveAsAction:extends{}

function SaveAction:execute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot save while testing.")
        return
    end

    if SB.projectDir == nil then
        self:super("execute")
    else
        local path = SB.projectDir
        Log.Notice("Saving project: " .. path .. " ...")
        self:Save(path)
    end
end
