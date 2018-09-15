SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

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
