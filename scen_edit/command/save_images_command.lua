SaveImagesCommand = Command:extends{}
SaveImagesCommand.className = "SaveImagesCommand"

function SaveImagesCommand:init(path, isNewProject)
    self.className = "SaveImagesCommand"
    self.path = path
    self.isNewProject = isNewProject
end

function SaveImagesCommand:__GetTexturePath(i, j)
    return Path.Join(self.path, "texture-" .. tostring(i) .. "-" .. tostring(j) .. ".png")
end

function SaveImagesCommand:execute()
    SB.delayGL(function()
    Time.MeasureTime(function()

        local texSize = SB.model.textureManager.TEXTURE_SIZE
        local sizeX = math.floor(Game.mapSizeX / texSize)
        local sizeZ = math.floor(Game.mapSizeZ / texSize)

        -- We clear all textures when it's a new project
        if self.isNewProject then
            for _, file in pairs(VFS.DirList(self.path, "texture-*-*.png")) do
                Log.Notice(("Removing %s.."):format(file))
                -- remove existing texture)
                os.remove(file)
            end
        end

        SaveShadingTextures(self.path)

        -- We're saving the map in parts
        for i = 0, sizeX do
            for j = 0, sizeZ do
                Spring.ClearWatchDogTimer()

                local mapTextureObj = SB.model.textureManager.mapFBOTextures[i][j]
                -- only write those textures that have changed since last save
                if mapTextureObj.dirty then
                    local mapTexture = mapTextureObj.texture

                    local mapTexturePath = self:__GetTexturePath(i, j)
                    -- remove existing texture)
                    os.remove(mapTexturePath)
                    Log.Debug("Saving subtexture", i, j, mapTexturePath)
                    gl.RenderToTexture(mapTexture, gl.SaveImage, 0, 0, texSize, texSize, mapTexturePath, {yflip=true})
                    mapTextureObj.dirty = false

                    -- all other textures on the undo/redo stack need to be set "dirty" so undoing + saving would change things
                    for _, s in pairs(SB.model.textureManager.stack) do
                        -- we only do this for the corresponding textures
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
        Log.Notice(("[%.4fs] Saved diffuse."):format(elapsed))
    end) -- end Time.MeasureTime
    end) -- end SB.delayGL
end
