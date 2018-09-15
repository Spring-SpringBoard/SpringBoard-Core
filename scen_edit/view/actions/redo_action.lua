SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

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
