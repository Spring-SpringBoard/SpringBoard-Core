SelectAllAction = LCS.class{}

function SelectAllAction:execute()
    local selection = {}
    for name, objectBridge in pairs(ObjectBridge.GetObjectBridges()) do
        if objectBridge.spGetAllObjects then
            selection[name] = objectBridge.spGetAllObjects()
        end
    end
    SB.view.selectionManager:Select(selection)
end
