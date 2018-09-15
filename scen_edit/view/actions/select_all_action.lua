SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

SelectAllAction = Action:extends{}

SelectAllAction:Register({
    name = "sb_select_all",
    hotkey = {
        key = KEYSYMS.A,
        ctrl = true,
    },
    limit_state = true,
})

function SelectAllAction:execute()
    local selection = {}
    for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        if bridge.s11n and bridge.s11n.GetAllObjectIDs then
            selection[name] = bridge.s11n:GetAllObjectIDs()
        end
    end
    SB.view.selectionManager:Select(selection)
end