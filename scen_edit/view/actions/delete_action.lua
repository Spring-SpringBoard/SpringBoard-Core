DeleteAction = LCS.class{}

function DeleteAction:execute()
    local selection = SB.view.selectionManager:GetSelection()

    local commands = {}
    for objType, selected in pairs(selection) do
        local objectBridge = ObjectBridge.GetObjectBridge(objType)
        for _, objectID in pairs(selected) do
            local modelID = objectBridge.getObjectModelID(objectID)
            local cmd = RemoveObjectCommand(objType, modelID)
            table.insert(commands, cmd)
        end
    end
    if #commands == 0 then
        return
    end
    local cmd = CompoundCommand(commands)
    SB.commandManager:execute(cmd)
end
