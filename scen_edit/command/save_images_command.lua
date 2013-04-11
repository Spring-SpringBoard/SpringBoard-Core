SaveImagesCommand = AbstractCommand:extends{}
SaveImagesCommand.className = "SaveImagesCommand"

function SaveImagesCommand:init(path)
    self.className = "SaveImagesCommand"
    self.path = path
end

function SaveImagesCommand:execute()
    local heightmapPath = self.path .. "heightmap.png"
    local texturePath = self.path .. "texture.png"
    
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

    Spring.Echo("Saving the texture to ", texturePath)
    totalMapTexture = gl.CreateTexture(Game.mapSizeX, Game.mapSizeZ, {
        border = false,
        min_filter = GL.NEAREST,
        mag_filter = GL.NEAREST,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = true,
    })
    totalMapFBO = gl.CreateFBO({
        color0 = totalMapTexture
    })
    local texSize = SCEN_EDIT.model.tm.TEXTURE_SIZE 
    local sizeX = math.floor(Game.mapSizeX / texSize)
    local sizeZ = math.floor(Game.mapSizeZ / texSize)
    for i = 0, sizeX do
        for j = 0, sizeZ do
            mapTexture = SCEN_EDIT.model.tm.mapFBOTextures[i][j]
            mapFBO = gl.CreateFBO({
                color0 = mapTexture
            })           
            gl.BlitFBO(
                mapFBO, 0, 0, texSize, texSize,
                totalMapFBO, i * texSize, j * texSize, (i + 1) * texSize, (j + 1) * texSize)

            -- Saving the map texture partially works...
            --[[
            local mapTexturePath = "texture-" .. tostring(i) .. "-" .. tostring(j) .. ".png"
            Spring.Echo(i, j, mapTexturePath)
            gl.RenderToTexture(mapTexture, gl.SaveImage, 0, 0, texSize, texSize, mapTexturePath)--]]
        end
    end
    -- Either blitting isn't working, or FBOs aren't properly mapped to textures...?
    gl.RenderToTexture(totalMapTexture, gl.SaveImage, 0, 0, Game.mapSizeX, Game.mapSizeZ, texturePath)
end
