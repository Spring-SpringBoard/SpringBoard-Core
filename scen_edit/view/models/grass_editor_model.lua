GrassEditorModel = LCS.class{}

function GrassEditorModel:init()
end

function GrassEditorModel:GetFieldDefinitions()
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
        {type = "numeric", name = "grassDetail", value = Spring.GetConfigInt("GrassDetail"), min = 0, max = 10000, step = 0.1, title = "Detail:", tooltip = "'GrassDetail' engine parameter: controls how much grass is visible.This is unsynced and will not be saved."},
        {type = "numeric", name = "size", value = 100, min = 40, max = 2000, title = "Size:", tooltip = "Size of the paint brush"},
        {type = "numeric", name = "rotation", value = 0, min = -360, max = 360, title = "Rotation:", tooltip = "Rotation of the shape"},
    }
end

function GrassEditorModel:IsValidState(state)
    return state:is_A(GrassEditingState)
end

function GrassEditorModel:OnFieldChange(name, value)
    if name == "grassDetail" then
        Spring.SetConfigInt("GrassDetail", math.ceil(value), true)
    end
end
