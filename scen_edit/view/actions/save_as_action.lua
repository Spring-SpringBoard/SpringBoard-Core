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
    SaveProjectDialog():setConfirmDialogCallback(
        function(path)
            if not String.Starts(path, SB_PROJECTS_DIR) then
                return false
            end

            local name = path:sub(#SB_PROJECTS_DIR + 1, #path)
            SB.project:Save(name)
            return true
        end
    )
end
