SelectAllAction = LCS.class{}

function SelectAllAction:execute()
    local selection = {}
    for name, objectBridge in pairs(ObjectBridge.GetObjectBridges()) do
        if objectBridge.GetAllObjects then
            selection[name] = objectBridge.GetAllObjects()
        end
    end
    SB.view.selectionManager:Select(selection)
end
