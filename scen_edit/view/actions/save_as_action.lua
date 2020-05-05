SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

SaveProjectAsAction = Action:extends{}

SaveProjectAsAction:Register({
    name = "sb_save_project_as",
    tooltip = "Save project as...",
    image = Path.Join(SB.DIRS.IMG, 'save.png'),
    toolbar_order = 5,
    hotkey = {
        key = KEYSYMS.S,
        ctrl = true,
        shift = true,
    },
})

local ARBITRARY_TIME = Spring.GetGameFrame() + 30
function SaveProjectAsAction:canExecute()
    if Spring.GetGameFrame() < ARBITRARY_TIME then
        Log.Warning("Cannot save project until it has been completely loaded")
        return false
    end
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot save while testing.")
        return false
    end
    return true
end

function SaveProjectAsAction:execute()
    SaveProjectDialog():setConfirmDialogCallback(
        function(path)
            if not String.Starts(path, SB.DIRS.PROJECTS) then
                return false, 'Project must be saved in the "springboard/projects" directory'
            end

            local name = path:sub(#SB.DIRS.PROJECTS + 1, #path)
            SB.project:Save(name)
            return true
        end
    )
end
