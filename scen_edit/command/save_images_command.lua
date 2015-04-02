SaveImagesCommand = AbstractCommand:extends{}
SaveImagesCommand.className = "SaveImagesCommand"

function SaveImagesCommand:init(path)
    self.className = "SaveImagesCommand"
    self.path = path
end

function SaveImagesCommand:execute()
    SCEN_EDIT.delayGL(function()
--         local texturePath = self.path .. "/texture.png"
 
--         if VFS.FileExists(texturePath, VFS.RAW) then
--             Spring.Echo("removing the existing texture")
--             os.remove(texturePath)
--         end
        --[[
        local heightmapPath = self.path .. "/heightmap.png"
        Spring.Echo("Saving the heightmap to ", heightmapPath)

        heightmapTexture = gl.CreateTexture(Game.mapSizeX / 4, Game.mapSizeZ / 4, {
            border = false,
            min_filter = GL.NEAREST,
            mag_filter = GL.NEAREST,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })
        gl.RenderToTexture(heightmapTexture,
        function()
            gl.Texture("$heightmap")
            gl.TexRect(-1,-1, 1, 1,0, 0, 1, 1)
        end)
            
        gl.RenderToTexture(heightmapTexture, gl.SaveImage, 0, 0, Game.mapSizeX / 4, Game.mapSizeZ / 4, heightmapPath)
        --]]

--         Spring.Echo("Saving the texture to ", texturePath)
--         local totalMapTexture = gl.CreateTexture(Game.mapSizeX, Game.mapSizeZ, {
--             border = false,
--             min_filter = GL.NEAREST,
--             mag_filter = GL.NEAREST,
--             wrap_s = GL.CLAMP_TO_EDGE,
--             wrap_t = GL.CLAMP_TO_EDGE,
--             fbo = true,
--         })
--         local totalMapFBO = gl.CreateFBO({
--             color0 = totalMapTexture
--         })
        local texSize = SCEN_EDIT.textureManager.TEXTURE_SIZE 
        local sizeX = math.floor(Game.mapSizeX / texSize)
        local sizeZ = math.floor(Game.mapSizeZ / texSize)
        for i = 0, sizeX do
            for j = 0, sizeZ do
                local mapTextureObj = SCEN_EDIT.textureManager.mapFBOTextures[i][j]
                -- only write those textures that have changed since last save
                if mapTextureObj.dirty then
                    local mapTexture = mapTextureObj.texture
    --                 mapFBO = gl.CreateFBO({
    --                     color0 = mapTexture
    --                 })
    --                 gl.BlitFBO(
    --                     mapFBO, 0, 0, texSize, texSize,
    --                     totalMapFBO, i * texSize, (sizeZ - j) * texSize, (i + 1) * texSize, (sizeZ - j - 1) * texSize)

                    -- Saving the map texture partially works...
                    
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
        -- Either blitting isn't working, or FBOs aren't properly mapped to textures...?
--         gl.RenderToTexture(totalMapTexture, gl.SaveImage, 0, 0, Game.mapSizeX, Game.mapSizeZ, texturePath)
    end)
end
