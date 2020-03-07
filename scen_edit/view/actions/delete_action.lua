SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

DeleteAction = Action:extends{}

DeleteAction:Register({
    name = "sb_delete",
    tooltip = "Delete",
    hotkey = {
        key = KEYSYMS.DELETE
    },
    limit_state = true,
})

function DeleteAction:canExecute()
    return SB.view.selectionManager:GetSelectionCount() > 0
end

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
