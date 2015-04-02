SaveImagesCommand = AbstractCommand:extends{}
SaveImagesCommand.className = "SaveImagesCommand"

function SaveImagesCommand:init(path)
    self.className = "SaveImagesCommand"
    self.path = path
end

function SaveImagesCommand:execute()
    SCEN_EDIT.delayGL(function()
        if SCEN_EDIT.textureManager == nil then
            return
        end

        local texSize = SCEN_EDIT.textureManager.TEXTURE_SIZE 
        local sizeX = math.floor(Game.mapSizeX / texSize)
        local sizeZ = math.floor(Game.mapSizeZ / texSize)

        -- We're saving the map in parts
        for i = 0, sizeX do
            for j = 0, sizeZ do
                local mapTextureObj = SCEN_EDIT.textureManager.mapFBOTextures[i][j]
                -- only write those textures that have changed since last save
                if mapTextureObj.dirty then
                    local mapTexture = mapTextureObj.texture


                    local mapTexturePath = self.path .. "/texture-" .. tostring(i) .. "-" .. tostring(j) .. ".png"
                    Spring.Log("scened", LOG.DEBUG, "Saving subtexture", i, j, mapTexturePath)
                    gl.RenderToTexture(mapTexture, gl.SaveImage, 0, 0, texSize, texSize, mapTexturePath)
                    mapTextureObj.dirty = false

                    -- all other textures on the undo/redo stack need to be set "dirty" so undoing + saving would change things
                    for _, s in pairs(SCEN_EDIT.textureManager.stack) do
                        -- we only do this for the corresponding textures
                        if s[i] and s[i][j] then
                            Spring.Log("scened", LOG.DEBUG, "Making subtexture dirty", i, j)
                            local oldTextureObj = s[i][j]
                            oldTextureObj.dirty = true
                        end
                    end
                end
            end
        end
    end)
end
