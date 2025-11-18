TerrainSettingsEditorModel = LCS.class{}

function TerrainSettingsEditorModel:init()
end

function TerrainSettingsEditorModel:GetFieldDefinitions()
    return {
        {
            type = "group",
            fields = {
                {type = "boolean", name = "voidWater", title = "Void water:", tooltip = "Determines whether ground is rendered transparent where there should be water.", width = 140},
                {type = "boolean", name = "voidGround", title = "Void ground:", tooltip = "Determines whether ground can be rendered transparent.", width = 140},
            }
        },
        {type = "boolean", name = "splatDetailNormalDiffuseAlpha", title = "DNTS diffuse alpha:", tooltip = "Whether or not DNTS texture alpha channel should be treated as a diffuse luminance.", width = 290},
        {type = "asset", name = "detailTexture", title = "Detail texture:", tooltip = "Detail texture", rootDir = "detail/", width = 290},
        {type = "separator", name = "map-textures-sep", caption = "Map textures"},
    }
end

function TerrainSettingsEditorModel:GetMapTextures()
    local textures = {}
    local names = Table.GetKeys(SB.model.textureManager.shadingTextureDefs)
    table.sort(names)
    for _, name in ipairs(names) do
        local def = SB.model.textureManager.shadingTextureDefs[name]
        local engineName = def.engineName
        local texInfo = gl.TextureInfo(engineName)
        local exists = texInfo.xsize > 0 and texInfo.ysize > 0
        table.insert(textures, {
            name = name,
            engineName = engineName,
            exists = exists
        })
    end
    return textures
end

function TerrainSettingsEditorModel:UpdateMapRendering()
    if not gl.GetMapRendering then
        return nil
    end

    local params = {}
    params.voidWater = gl.GetMapRendering("voidWater")
    params.voidGround = gl.GetMapRendering("voidGround")
    params.splatDetailNormalDiffuseAlpha = gl.GetMapRendering("splatDetailNormalDiffuseAlpha")
    return params
end

function TerrainSettingsEditorModel:OnStartChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function TerrainSettingsEditorModel:OnEndChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function TerrainSettingsEditorModel:OnFieldChange(name, value, mapTextures, isLoading)
    if name == "detailTexture" then
        SB.delayGL(function()
            local texInfo = gl.TextureInfo(value)
            if texInfo == nil or texInfo.xsize <= 0 then
                return
            end
            gl.DeleteTexture(value)
            SB.model.textureManager:AssignShadingTexture("detail", value)
        end)
    elseif name == "voidWater" or name == "voidGround" or name == "splatDetailNormalDiffuseAlpha" then
        local t = {}
        t[name] = value
        local cmd = SetMapRenderingParamsCommand(t)
        SB.commandManager:execute(cmd)
    elseif mapTextures ~= nil and mapTextures[name] ~= nil then
        if isLoading then
            return
        end

        if value then
            local texName = mapTextures[name]
            local sizeX, sizeY

            if texName:find("splat_normals") then
                sizeX, sizeY = 512, 512
            else
                sizeX, sizeY = Game.mapSizeX / 4, Game.mapSizeZ / 4
            end

            local color
            if texName == "splat_distr" then
                color = {1, 0, 0, 0}
            elseif texName:find("splat_normals") then
                color = {0.5, 0.5, 1, 0.5}
            elseif texName == "emission" then
                color = {0.0, 0.0, 0.0, 0.2}
            elseif texName == "refl" then
                color = {0.0, 0.0, 0.0, 0.2}
            elseif texName == "specular" then
                color = {0.0, 0.0, 0.0, 1.0}
            end

            return {
                createDialog = true,
                name = name,
                engineName = mapTextures[name],
                sizeX = sizeX,
                sizeY = sizeY,
                color = color,
            }
        else
            SB.delayGL(function()
                SB.model.textureManager:ResetShadingTexture(mapTextures[name])
            end)
            SB.commandManager:execute(ClearUndoRedoCommand())
        end
    end
end
