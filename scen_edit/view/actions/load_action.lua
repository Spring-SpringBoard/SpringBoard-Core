SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

LoadAction = Action:extends{}

LoadAction:Register({
    name = "sb_load_project",
    tooltip = "Load Project",
    image = Path.Join(SB.DIRS.IMG, 'open-folder.png'),
    toolbar_order = 2,
    hotkey = {
        key = KEYSYMS.O,
        ctrl = true
    }
})

function LoadAction:canExecute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot load while testing.")
        return false
    end
    return true
end

function LoadAction:execute()
    OpenProjectDialog():setConfirmDialogCallback(
        function(path)
            SB.commandManager:execute(ReloadIntoProjectCommand(path), true)
        end
    )
end
