ExportMapsCommand = AbstractCommand:extends{}
ExportMapsCommand.className = "ExportMapsCommand"

function ExportMapsCommand:init(path)
    self.className = "ExportMapsCommand"
    self.path = path
end

function ExportMapsCommand:execute()
    SCEN_EDIT.delayGL(function()
        -- create dir just to be sure
        Spring.CreateDir(self.path)

        -- heightmap
        local heightmapPath = self.path .. "/heightmap.png"
        Spring.Echo("Saving the heightmap to " .. heightmapPath .. "...")

        if VFS.FileExists(heightmapPath, VFS.RAW) then
            Spring.Echo("removing the existing heightmap")
            os.remove(heightmapPath)
        end

        local texInfo = gl.TextureInfo("$heightmap")
        heightmapTexture = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })

        gl.Texture("$heightmap")
        gl.RenderToTexture(heightmapTexture,
        function()
            gl.TexRect(-1,-1, 1, 1)
        end)
        gl.Texture(false)

        gl.RenderToTexture(heightmapTexture, gl.SaveImage, 0, 0, texInfo.xsize, texInfo.ysize, heightmapPath)

        -- diffuse
        local texturePath = self.path .. "/texture.png"
 
        if VFS.FileExists(texturePath, VFS.RAW) then
            Spring.Echo("removing the existing texture")
            os.remove(texturePath)
        end

        Spring.Echo("Saving the texture to " .. texturePath .. "...")
        local totalMapTexture = gl.CreateTexture(Game.mapSizeX, Game.mapSizeZ, {
            border = false,
            min_filter = GL.NEAREST,
            mag_filter = GL.NEAREST,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })
        local totalMapFBO = gl.CreateFBO({
            color0 = totalMapTexture
        })
        local texSize = SCEN_EDIT.model.textureManager.TEXTURE_SIZE
        local sizeX = math.floor(Game.mapSizeX / texSize)
        local sizeZ = math.floor(Game.mapSizeZ / texSize)
        for i = 0, sizeX do
            for j = 0, sizeZ do
                local mapTextureObj = SCEN_EDIT.model.textureManager.mapFBOTextures[i][j]
                -- only write those textures that have changed since last save

                local mapTexture = mapTextureObj.texture
                mapFBO = gl.CreateFBO({
                    color0 = mapTexture
                })
                gl.BlitFBO(
                    mapFBO, 0, 0, texSize, texSize,
                    totalMapFBO, i * texSize, (sizeZ - j) * texSize, (i + 1) * texSize, (sizeZ - j - 1) * texSize)
            end
        end
        -- Either blitting isn't working, or FBOs aren't properly mapped to textures...?
        gl.RenderToTexture(totalMapTexture, gl.SaveImage, 0, 0, Game.mapSizeX, Game.mapSizeZ, texturePath)
        -- FIXME: probably not needed -.-
        gl.Flush()
    end)
end
