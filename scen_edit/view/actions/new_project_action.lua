SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

NewProjectAction = Action:extends{}

NewProjectAction:Register({
    name = "sb_new_project",
    tooltip = "New project",
    image = SB_IMG_DIR .. "file.png",
    toolbar_order = 1,
    hotkey = {
        key = KEYSYMS.N,
        ctrl = true
    },
})

function NewProjectAction:canExecute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot make new project while testing.")
        return false
    end
    return true
end

function NewProjectAction:execute()
    -- FIXME: Full new project support needs an engine update.
    NewProjectDialog()
end

