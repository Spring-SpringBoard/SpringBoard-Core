MetalEditorModel = LCS.class{}

function MetalEditorModel:init()
end

function MetalEditorModel:GetFieldDefinitions()
    return {
        {
            type = "asset",
            name = "patternTexture",
            title = "Pattern:",
            rootDir = "brush_patterns/terrain/",
            expand = true,
            itemWidth = 65,
            itemHeight = 65,
            validateFunc = function(obj, value)
                if value == nil then
                    return true
                end
                if not AssetField.Validate(obj, value) then
                    return false
                end
                local ext = Path.GetExt(value) or ""
                return table.ifind(SB_IMG_EXTS, ext), value
            end,
            updateFunc = function(value)
                SB.model.terrainManager:generateShape(value)
            end
        },
        {type = "numeric", name = "size", value = 100, min = 40, max = 1000, title = "Size:", tooltip = "Size of the paint brush"},
        {type = "numeric", name = "rotation", value = 0, min = -360, max = 360, title = "Rotation:", tooltip = "Rotation of the shape"},
        {type = "numeric", name = "amount", value = 50, min = 0, max = 5.1, title = "Amount:", tooltip = "Amount of metal"},
    }
end

function MetalEditorModel:IsValidState(state)
    return state:is_A(MetalEditingState)
end

function MetalEditorModel:ShowMetalMap()
    Spring.SendCommands('showmetalmap')
end
