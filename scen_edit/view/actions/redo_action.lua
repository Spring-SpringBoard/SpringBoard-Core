SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

RedoAction = Action:extends{}

RedoAction:Register({
    name = "sb_redo",
    tooltip = "Redo",
    toolbar_order = 102,
    hotkey = {
        key = KEYSYMS.Y,
        ctrl = true,
    }
})

function RedoAction:execute()
    SB.commandManager:execute(RedoCommand())
end
