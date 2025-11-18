TextureEditorModel = LCS.class{}

function TextureEditorModel:init()
    self.listeners = {}
    self.currentMode = "paint"
end

function TextureEditorModel:AddListener(listener)
    table.insert(self.listeners, listener)
end

function TextureEditorModel:NotifyListeners(event, ...)
    for _, listener in ipairs(self.listeners) do
        if listener[event] then
            listener[event](listener, ...)
        end
    end
end

function TextureEditorModel:GetFieldDefinitions()
    local fields = {
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
                local ext = Path.GetExt(value) or ""
                return table.ifind(SB_IMG_EXTS, ext), value
            end
        },
        {
            type = "material",
            name = "brushTexture",
            title = "Texture:",
            value = {},
            rootDir = "brush_textures/",
            width = 200,
        },
        {
            type = "choice",
            name = "mode",
            items = {
                "Normal", "Darken", "Lighten", "SoftLight", "HardLight", "Luminance",
                "Multiply", "Premultiplied", "Overlay", "Screen", "Add", "Subtract",
                "Difference", "InverseDifference", "Exclusion", "Color", "ColorBurn", "ColorDodge",
            },
            title = "Mode:"
        },
        {
            type = "choice",
            name = "kernelMode",
            items = {
                "blur", "bottom_sobel", "emboss", "left_sobel", "outline",
                "right_sobel", "sharpen", "top sobel",
            },
            title = "Filter:"
        },
        {
            type = "boolean",
            name = "exclusive",
            title = "Exclusive: ",
            value = false,
        },
        {
            type = "separator",
            name = "offset-sep",
            caption = "Pattern",
        },
        {
            type = "group",
            fields = {
                {type = "numeric", name = "size", value = 100, min = 1, max = 5000, title = "Size:", tooltip = "Size of the paint brush", width = 140},
                {type = "numeric", name = "rotation", value = 0, min = -360, max = 360, title = "Rotation:", tooltip = "Rotation of the paint brush", width = 140},
                {type = "numeric", name = "texScale", value = 2, min = 0.01, step = 0.05, title = "Scale:", tooltip = "Texture sampling rate (larger number means higher frequency)", width = 140},
            }
        },
        {
            type = "separator",
            name = "tex-sep",
            caption = "Material",
        },
        {
            type = "group",
            fields = {
                {type = "numeric", name = "texRotation", value = 0, min = -360, max = 360, title = "Tex rotation:", tooltip = "Rotation of the texture", width = 140},
                {type = "numeric", name = "texOffsetX", value = 0, min = -1, max = 1, step = 0.001, title = "X:", tooltip = "Texture offset X", width = 140},
                {type = "numeric", name = "texOffsetY", value = 0, min = -1, max = 1, step = 0.001, title = "Y:", tooltip = "Texture offset Y", width = 140},
            }
        },
        {
            type = "separator",
            name = "blending-sep",
            caption = "Blending",
        },
        {
            type = "group",
            fields = {
                {type = "numeric", name = "strength", value = 1, min = 0.0, max = 1, title = "Strength:", tooltip = "Application strength (use lower numbers for finer detail painting)", width = 140},
                {type = "numeric", name = "falloffFactor", value = 0.3, min = 0.0, max = 1, title = "Falloff:", tooltip = "Texture painting fade out (1 means crisp)", width = 140},
                {type = "numeric", name = "featureFactor", value = 1, min = 0.0, max = 1, title = "Feature:", tooltip = "Feature filtering (1 means no filter filtering)", width = 140},
            }
        },
        {type = "numeric", name = "value", value = 1, min = 0.0, max = 1, title = "Value:", tooltip = "Goal value to be set for DNTS textures when painting.", width = 140},
        {type = "numeric", name = "voidFactor", value = 1, min = 0.0, max = 1, title = "Transparency:", tooltip = "The greater the value, the more transparent it will be.", width = 140},
        {
            type = "separator",
            name = "splat-sep",
            caption = "Splat",
        },
        {
            type = "group",
            fields = {
                {type = "numeric", name = "splatTexScale", value = 1, step = 0.000001, decimals = 6, title = "Scale:", tooltip = "Splat texture multiplier", width = 140},
                {type = "numeric", name = "splatTexMult", value = 0.5, step = 0.01, title = "Mult:", tooltip = "Splat texture multiplier", width = 140},
            }
        },
        {type = "color", name = "diffuseColor", title = "Color: ", value = {1, 1, 1, 1}, width = 140, format = 'rgb'},
        {type = "hidden", name = "dntsIndex", value = 0},
    }

    return fields
end

function TextureEditorModel:GetMaterialTextureFields()
    local matFields = {}
    for name, _ in pairs(SB.model.textureManager.materialTextures) do
        if name ~= "normal" then
            local fname = name .. "Enabled"
            table.insert(matFields, {
                type = "boolean",
                name = fname,
                value = true,
                title = String.Capitalize(name) .. ":",
                tooltip = String.Capitalize(name) .. " texture",
                width = 140,
            })
        end
    end
    return matFields
end

function TextureEditorModel:GetToolModes()
    return {
        {
            id = "paint",
            caption = "Paint",
            tooltip = "Paint the terrain",
            icon = "large-paint-brush.png",
        },
        {
            id = "blur",
            caption = "Filter",
            tooltip = "Apply a filter",
            icon = "filter-brush.png",
        },
        {
            id = "dnts",
            caption = "DNTS",
            tooltip = "DNTS textures",
            icon = "paint-brush.png",
        },
        {
            id = "void",
            caption = "Void",
            tooltip = "Make the terrain transparent",
            icon = "large-paint-brush.png",
        },
    }
end

function TextureEditorModel:GetVisibleFieldsForMode(mode)
    local matFieldNames = {}
    for name, _ in pairs(SB.model.textureManager.materialTextures) do
        if name ~= "normal" then
            table.insert(matFieldNames, name .. "Enabled")
        end
    end

    if mode == "paint" then
        local fields = {"patternTexture", "brushTexture", "mode", "size", "rotation", "texScale",
                       "texRotation", "texOffsetX", "texOffsetY", "strength", "falloffFactor",
                       "featureFactor", "diffuseColor", "offset-sep", "tex-sep", "blending-sep"}
        for _, name in ipairs(matFieldNames) do
            table.insert(fields, name)
        end
        return fields
    elseif mode == "blur" then
        return {"patternTexture", "size", "rotation", "falloffFactor", "kernelMode",
                "offset-sep", "blending-sep"}
    elseif mode == "dnts" then
        return {"patternTexture", "brushTexture", "size", "rotation", "falloffFactor",
                "exclusive", "value", "splatTexScale", "splatTexMult", "splat-sep", "blending-sep"}
    elseif mode == "void" then
        return {"patternTexture", "size", "rotation", "falloffFactor", "voidFactor",
                "offset-sep", "blending-sep"}
    end
    return {}
end

function TextureEditorModel:SetMode(mode)
    self.currentMode = mode
    self:NotifyListeners("OnModeChanged", mode)
end

function TextureEditorModel:GetCurrentMode()
    return self.currentMode
end

function TextureEditorModel:IsValidState(state)
    return state:is_A(TerrainChangeTextureState)
end

function TextureEditorModel:GetDNTSIndex(fields)
    return fields["dntsIndex"].value
end

function TextureEditorModel:OnStartChange(name)
    if name == "splatTexScale" or name == "splatTexMult" then
        SB.commandManager:execute(SetMultipleCommandModeCommand(true))
    end
end

function TextureEditorModel:OnEndChange(name)
    if name == "splatTexScale" or name == "splatTexMult" then
        SB.commandManager:execute(SetMultipleCommandModeCommand(false))
    end
end

function TextureEditorModel:HandleFieldChange(name, value, savedBrushes, savedDNTSBrushes, fields)
    if savedBrushes:GetControl().visible then
        local brush = savedBrushes:GetSelectedBrush()
        if brush then
            savedBrushes:UpdateBrush(brush.brushID, name, value)
            if name == "brushTexture" or name == "texOffsetX" or name == "texOffsetY"
                or name == "diffuseColor" or name == "texRotation" or name == "texScale" then
                if name == "brushTexture" then
                    SB.commandManager:execute(CacheTextureCommand(value))
                end
                savedBrushes:RefreshBrushImage(brush.brushID)
            end
        end
    elseif savedDNTSBrushes:GetControl().visible then
        local brush = savedDNTSBrushes:GetSelectedBrush()
        if brush then
            savedDNTSBrushes:UpdateBrush(brush.brushID, name, value)
            if name == "brushTexture" then
                savedDNTSBrushes:RefreshBrushImage(brush.brushID)
            end
        end
    end

    if name == "brushTexture" and savedDNTSBrushes:GetControl().visible then
        local dntsIndex = self:GetDNTSIndex(fields)
        local material = fields["brushTexture"].value
        if dntsIndex and material.normal then
            SB.delayGL(function()
                SB.model.textureManager:SetDNTS(dntsIndex, material)
            end)
        end
    elseif name == "splatTexScale" or name == "splatTexMult" then
        local index = self:GetDNTSIndex(fields)
        local tbl = {gl.GetMapRendering(name .. "s")}
        tbl[index+1] = value
        local t = {
            [name .. "s"] = tbl,
        }
        local cmd = SetMapRenderingParamsCommand(t)
        SB.commandManager:execute(cmd)
    end
end
