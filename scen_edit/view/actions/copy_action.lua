SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

CopyAction = Action:extends{}

CopyAction:Register({
    name = "sb_copy",
    tooltip = "Copy",
    image = SB_IMG_DIR .. "copy.png",
    toolbar_order = 103,
    hotkey = {
        key = KEYSYMS.C,
        ctrl = true,
    },
    limit_state = true
})

function CopyAction:canExecute()
    return SB.view.selectionManager:GetSelectionCount() > 0
end

function CopyAction:execute()
    SB.clipboard:Copy(SB.view.selectionManager:GetSelection())
end