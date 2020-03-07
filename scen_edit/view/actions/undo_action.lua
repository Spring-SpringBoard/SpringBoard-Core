SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

UndoAction = Action:extends{}

UndoAction:Register({
    name = "sb_undo",
    tooltip = "Undo",
    toolbar_order = 101,
    hotkey = {
        key = KEYSYMS.Z,
        ctrl = true,
    }
})

function UndoAction:execute()
    SB.commandManager:execute(UndoCommand())
end
