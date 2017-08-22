SelectAllAction = LCS.class{}

function SelectAllAction:execute()
    local selection = {}
    for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        if bridge.s11n and bridge.s11n.GetAllObjectIDs then
            selection[name] = bridge.s11n:GetAllObjectIDs()
        end
    end
    SB.view.selectionManager:Select(selection)
end
