HeightmapEditorModel = LCS.class{}

function HeightmapEditorModel:init()
    self.listeners = {}
    self.currentMode = "add"  -- add, set, smooth
end

function HeightmapEditorModel:AddListener(listener)
    table.insert(self.listeners, listener)
end

function HeightmapEditorModel:NotifyListeners(event, ...)
    for _, listener in ipairs(self.listeners) do
        if listener[event] then
            listener[event](listener, ...)
        end
    end
end

function HeightmapEditorModel:GetFieldDefinitions()
    return {
        {
            type = "asset",
            name = "patternTexture",
            title = "Pattern:",
            rootDir = "brush_patterns/terrain/",
            expand = true,
            itemWidth = 65,
            itemHeight = 65,
            validateFunc = function(value)
                if not value then
                    return true
                end
                local ext = Path.GetExt(value) or ""
                return table.ifind(SB_IMG_EXTS, ext), value
            end,
            updateFunc = function(value)
                SB.model.terrainManager:generateShape(value)
            end
        },
        {
            type = "numeric",
            name = "size",
            value = 100,
            min = 10,
            max = 5000,
            title = "Size:",
            tooltip = "Size of the height brush",
        },
        {
            type = "numeric",
            name = "rotation",
            value = 0,
            min = -360,
            max = 360,
            title = "Rotation:",
            tooltip = "Rotation of the shape",
        },
        {
            type = "numeric",
            name = "strength",
            value = 10,
            step = 0.1,
            title = "Strength:",
            tooltip = "Strength of the height map tool",
        },
        {
            type = "numeric",
            name = "height",
            value = 10,
            step = 0.1,
            title = "Height:",
            tooltip = "Goal height",
        },
        {
            type = "choice",
            name = "applyDir",
            items = {"Both", "Only Raise", "Only Lower"},
            tooltip = "Whether terrain should be only lowered, raised or both.",
        },
    }
end

function HeightmapEditorModel:GetToolModes()
    return {
        {
            id = "add",
            caption = "Add",
            tooltip = "Left Click to add height, Right Click to remove height",
            icon = "up-card.png",
            stateClass = "TerrainShapeModifyState",
        },
        {
            id = "set",
            caption = "Set",
            tooltip = "Left Click to set height. Right click to sample height",
            icon = "terrain-set.png",
            stateClass = "TerrainSetState",
        },
        {
            id = "smooth",
            caption = "Smooth",
            tooltip = "Click to smooth terrain",
            icon = "terrain-smooth.png",
            stateClass = "TerrainSmoothState",
        },
    }
end

function HeightmapEditorModel:GetVisibleFieldsForMode(mode)
    if mode == "add" or mode == "smooth" then
        return {"patternTexture", "size", "rotation", "strength", "height"}
    elseif mode == "set" then
        return {"patternTexture", "size", "rotation", "strength", "height", "applyDir"}
    end
    return {}
end

function HeightmapEditorModel:SetMode(mode)
    self.currentMode = mode
    self:NotifyListeners("OnModeChanged", mode)
end

function HeightmapEditorModel:GetCurrentMode()
    return self.currentMode
end

function HeightmapEditorModel:ActivateTool(modeId, editor)
    self:SetMode(modeId)

    if modeId == "add" then
        SB.stateManager:SetState(TerrainShapeModifyState(editor))
    elseif modeId == "set" then
        SB.stateManager:SetState(TerrainSetState(editor))
    elseif modeId == "smooth" then
        SB.stateManager:SetState(TerrainSmoothState(editor))
    end
end

function HeightmapEditorModel:ShowElevation()
    Spring.SendCommands('showelevation')
end

function HeightmapEditorModel:IsValidState(state)
    return state:is_A(AbstractHeightmapEditingState)
end
