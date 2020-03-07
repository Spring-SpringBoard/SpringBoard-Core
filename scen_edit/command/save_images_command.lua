SaveImagesCommand = Command:extends{}
SaveImagesCommand.className = "SaveImagesCommand"

function SaveImagesCommand:init(path, isNewProject)
    self.path = path
    self.isNewProject = isNewProject
end

function SaveImagesCommand:__GetTexturePath(i, j)
    return Path.Join(self.path, "texture-" .. tostring(i) .. "-" .. tostring(j) .. ".png")
end

local function SaveShadingTextures(path, prefix)
    for texType, shadingTexObj in pairs(SB.model.textureManager.shadingTextures) do
        if shadingTexObj.dirty or self.isNewProject then
            SB.WriteShadingTextureToFile(texType, Path.Join(path, prefix .. texType .. ".png"))

            shadingTexObj.dirty = false
            -- all other textures on the undo/redo stack need to be set "dirty" so undoing + saving would change things
            for _, stackItem in pairs(SB.model.textureManager.stack) do
                -- we only do this for the corresponding texture
                local oldTextureObj = stackItem[texType]
                if oldTextureObj then
                    Log.Debug("Making shading texture dirty: " .. tostring(texType))
                    oldTextureObj.dirty = true
                end
            end
        end
    end
end

function SaveImagesCommand:execute()
    SB.delayGL(function()
    Time.MeasureTime(function()
        Spring.ClearWatchDogTimer(nil, true)

        local texSize = SB.model.textureManager.TEXTURE_SIZE
        local sizeX = math.floor(Game.mapSizeX / texSize)
        local sizeZ = math.floor(Game.mapSizeZ / texSize)

        -- We clear all textures when it's a new project
        if self.isNewProject then
            for _, file in ipairs(Path.DirList(self.path, "texture-*-*.png")) do
                Log.Notice(("Removing %s.."):format(file))
                -- remove existing texture)
                os.remove(file)
            end
        end

        SaveShadingTextures(self.path, "shading-")

        -- We're saving the map in parts
        for i = 0, sizeX do
            for j = 0, sizeZ do
                local mapTextureObj = SB.model.textureManager.mapFBOTextures[i][j]
                -- only write those textures that have changed since last save
                if mapTextureObj.dirty or self.isNewProject then
                    local mapTexture = mapTextureObj.texture

                    local mapTexturePath = self:__GetTexturePath(i, j)
                    -- remove existing texture)
                    os.remove(mapTexturePath)
                    Log.Debug("Saving subtexture", i, j, mapTexturePath)
                    gl.RenderToTexture(mapTexture, gl.SaveImage, 0, 0, texSize, texSize, mapTexturePath, {yflip=false})
                    mapTextureObj.dirty = false

                    -- all other textures on the undo/redo stack need to be set "dirty" so undoing + saving would change things
                    for _, stackItem in pairs(SB.model.textureManager.stack) do
                        -- we only do this for the corresponding textures
                        local s = stackItem.diffuse
                        if s[i] and s[i][j] then
                            Log.Debug("Making subtexture dirty", i, j)
                            local oldTextureObj = s[i][j]
                            oldTextureObj.dirty = true
                        end
                    end
                end
            end
        end

    end, function(elapsed)
        Spring.ClearWatchDogTimer(nil, false)
        Log.Notice(("[%.4fs] Saved texture."):format(elapsed))
    end) -- end Time.MeasureTime
    end) -- end SB.delayGL
end
