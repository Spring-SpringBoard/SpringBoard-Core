SB.Include(SB_VIEW_ACTIONS_DIR .. "save_as_action.lua")

SaveProjectAction = SaveProjectAsAction:extends{}

SaveProjectAction:Register({
    name = "sb_save_project",
    tooltip = "Save project",
    image = SB_IMG_DIR .. "save.png",
    toolbar_order = 4,
    hotkey = {
        key = KEYSYMS.S,
        ctrl = true
    },
})

function SaveProjectAction:canExecute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot save while testing.")
        return false
    end
    return true
end

function SaveProjectAction:execute()
    if SB.project.path == nil then
        self:super("execute")
    else
        SB.project:Save()
    end
end
