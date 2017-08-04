NewAction = AbstractAction:extends{}

function NewAction:execute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot make new project while testing.")
        return
    end

    NewProjectDialog()
end
