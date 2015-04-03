LoadTextureCommand = AbstractCommand:extends{}
LoadTextureCommand.className = "LoadTextureCommand"

function LoadTextureCommand:init(texturePath)
    self.className = "LoadTextureCommand"
    self.texturePath = texturePath
end

function LoadTextureCommand:execute()
    if not VFS.FileExists(self.texturePath) then
        Spring.Echo("Missing texture file: " .. tostring(self.texturePath))
        return
    end

    Spring.Echo("Loading textures..")
    SCEN_EDIT.delayGL(function()
        totalMapTexture = gl.CreateTexture(Game.mapSizeX, Game.mapSizeZ, {
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
        gl.RenderToTexture(totalMapTexture,
        function()
            gl.Texture(self.texturePath)
            gl.TexRect(-1,-1, 1, 1,0, 0, 1, 1)
        end)


        local texSize = SCEN_EDIT.model.textureManager.TEXTURE_SIZE 
        local sizeX = math.floor(Game.mapSizeX / texSize)
        local sizeZ = math.floor(Game.mapSizeZ / texSize)
        for i = 0, sizeX do
            for j = 0, sizeZ do
                mapTexture = SCEN_EDIT.model.textureManager.mapFBOTextures[i][j]
                mapFBO = gl.CreateFBO({
                    color0 = mapTexture
                })           
                gl.BlitFBO(
                    totalMapFBO, i * texSize, j * texSize, (i + 1) * texSize, (j + 1) * texSize, mapFBO, 0, 0, texSize, texSize)

                -- Saving the map texture partially works...
                
                --local mapTexturePath = self.path .. "/texture-" .. tostring(i) .. "-" .. tostring(j) .. ".png"
                --Spring.Echo(i, j, mapTexturePath)
                --gl.RenderToTexture(mapTexture, gl.SaveImage, 0, 0, texSize, texSize, mapTexturePath)
            end
        end
    end)
end
