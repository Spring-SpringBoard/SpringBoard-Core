ExportMapsCommand = Command:extends{}
ExportMapsCommand.className = "ExportMapsCommand"

function ExportMapsCommand:init(path, heightmapExtremes)
    self.path = path
    self.heightmapExtremes = heightmapExtremes
end

function SaveShadingTextures(path, toProject, prefix)
    -- FIXME: Maybe totally get rid of this prefix thing?
    if not prefix then
        prefix = ""
    end
    for texType, shadingTexObj in pairs(SB.model.textureManager.shadingTextures) do
        if shadingTexObj.dirty or not toProject then
            local texPath = Path.Join(path, prefix .. texType .. ".png")
            if VFS.FileExists(texPath, VFS.RAW) then
                Log.Notice("Removing existing texture: " .. tostring(texPath))
                os.remove(texPath)
            end

            Log.Notice("Saving " .. texType .. " to " .. texPath .. "...")
            local texture = shadingTexObj.texture
            local texInfo = gl.TextureInfo(texture)

            local texDef = SB.model.textureManager.shadingTextureDefs[texType]
            local alpha = not not texDef.alpha
            gl.Blending("enable")
            gl.RenderToTexture(texture, gl.SaveImage, 0, 0, texInfo.xsize, texInfo.ysize, texPath, {alpha=alpha, yflip=true})

            if toProject then
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
end

function ExportMapsCommand:GetShaderObj()
    if not ExportMapsCommand.shaderObj then
        local heightmapScaleShader = [[
            uniform sampler2D heightmapTex;
            uniform float groundMin, groundMax;
            void main() {
                gl_FragColor = texture2D(heightmapTex, gl_TexCoord[0].st);
                gl_FragColor.rgb = (gl_FragColor.rgb - groundMin) / (groundMax - groundMin);
            }
        ]]

        local shader = Shaders.Compile({
            fragment = heightmapScaleShader,
            uniformInt = {heightmapTexID = 0 },
        }, "ExportMapsShader")
        if not shader then
            return
        end
        ExportMapsCommand.shaderObj = {
            shader = shader,
            uniforms = {
                heightmapTexID = gl.GetUniformLocation(shader, "heightmapTex"),
                groundMaxID    = gl.GetUniformLocation(shader, "groundMax"),
                groundMinID    = gl.GetUniformLocation(shader, "groundMin"),
            }
        }
    end

    return ExportMapsCommand.shaderObj
end

function ExportMapsCommand:ExportHeightmap()
    local heightmapPath = Path.Join(self.path, "heightmap.png")

    Log.Notice("Saving the heightmap to " .. heightmapPath .. "...")

    if VFS.FileExists(heightmapPath, VFS.RAW) then
        Log.Notice("Removing the existing heightmap")
        os.remove(heightmapPath)
    end

    local texInfo = gl.TextureInfo("$heightmap")
    local GL_LUMINANCE32F_ARB = 0x8818
    if Platform.osFamily == "Windows" then
        GL_LUMINANCE32F_ARB = nil
    end
    local heightmapTexture = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
        format = GL_LUMINANCE32F_ARB,
        border = false,
        min_filter = GL.NEAREST,
        mag_filter = GL.NEAREST,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = true,
    })

    local minHeight, maxHeight
    if self.heightmapExtremes ~= nil then
        minHeight, maxHeight = self.heightmapExtremes[1], self.heightmapExtremes[2]
    else
        minHeight, maxHeight = math.huge, -math.huge
        for x = 0, Game.mapSizeX, Game.squareSize do
            for z = 0, Game.mapSizeZ, Game.squareSize do
                local groundHeight = Spring.GetGroundHeight(x, z)
                if groundHeight > maxHeight then
                    maxHeight = groundHeight
                end
                if groundHeight < minHeight then
                    minHeight = groundHeight
                end
            end
        end
    end
    Log.Notice("Exporting heightmap with extremes: " ..
                tostring(minHeight) .. " and " .. tostring(maxHeight))

    local shaderObj = self:GetShaderObj()
    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.uniforms.groundMaxID, maxHeight)
    gl.Uniform(shaderObj.uniforms.groundMinID, minHeight)
    gl.Texture(0, "$heightmap")
    gl.RenderToTexture(heightmapTexture,
    function()
        gl.TexRect(-1,-1, 1, 1)
    end)
    gl.Texture(0, false)
    gl.UseShader(0)

    local useGrayscale16bit = true
    if Platform.osFamily == "Windows" then
        useGrayscale16bit = false
    end
    gl.RenderToTexture(heightmapTexture, gl.SaveImage, 0, 0, texInfo.xsize, texInfo.ysize, heightmapPath, {grayscale16bit = useGrayscale16bit})
    gl.DeleteTexture(heightmapTexture)
end

function ExportMapsCommand:ExportGrass()
    local grassPath = Path.Join(self.path, "grass.png")
    Log.Notice("Saving the grass to " .. grassPath .. "...")

    if VFS.FileExists(grassPath, VFS.RAW) then
        Log.Notice("removing the existing grass")
        os.remove(grassPath)
    end

    local texInfo = gl.TextureInfo("$grass")
    local grassTexture = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = true,
    })

    gl.Texture("$grass")
    gl.RenderToTexture(grassTexture,
    function()
        gl.TexRect(-1,-1, 1, 1)
    end)
    gl.Texture(false)

    gl.RenderToTexture(grassTexture, gl.SaveImage, 0, 0, texInfo.xsize, texInfo.ysize, grassPath)
    gl.DeleteTexture(grassTexture)
end

function ExportMapsCommand:ExportDiffuse()
    local texturePath = Path.Join(self.path, "diffuse.png")

    if VFS.FileExists(texturePath, VFS.RAW) then
        Log.Notice("removing the existing texture")
        os.remove(texturePath)
    end

    Log.Notice("Saving the texture to " .. texturePath .. "...")
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
    local texSize = SB.model.textureManager.TEXTURE_SIZE
    local sizeX = math.floor(Game.mapSizeX / texSize)
    local sizeZ = math.floor(Game.mapSizeZ / texSize)
    local mapFBO
    for i = 0, sizeX do
        for j = 0, sizeZ do
            Spring.ClearWatchDogTimer()

            local mapTextureObj = SB.model.textureManager.mapFBOTextures[i][j]

            local mapTexture = mapTextureObj.texture
            mapFBO = gl.CreateFBO({
                color0 = mapTexture
            })
            gl.BlitFBO(
                mapFBO, 0, 0, texSize, texSize,
                totalMapFBO, i * texSize, (sizeZ - j) * texSize, (i + 1) * texSize, (sizeZ - j - 1) * texSize)
            gl.DeleteFBO(mapFBO)
        end
    end
    -- Either blitting isn't working, or FBOs aren't properly mapped to textures...?
    Spring.ClearWatchDogTimer()
    gl.RenderToTexture(totalMapTexture, gl.SaveImage, 0, 0, Game.mapSizeX, Game.mapSizeZ, texturePath)
    gl.DeleteTexture(totalMapTexture)
    -- FIXME: probably not needed -.-
    gl.Flush()
end

function ExportMapsCommand:execute()
    SB.delayGL(function()
        -- create dir just to be sure
        Spring.CreateDir(self.path)

        Time.MeasureTime(function()
            self:ExportHeightmap()
        end, function (elapsed)
            Log.Notice(("[%.4fs] Exported heightmap"):format(elapsed))
        end)
        Time.MeasureTime(function()
            self:ExportGrass()
        end, function (elapsed)
            Log.Notice(("[%.4fs] Exported grass"):format(elapsed))
        end)
        Time.MeasureTime(function()
            SaveShadingTextures(self.path, false, "")
        end, function (elapsed)
            Log.Notice(("[%.4fs] Exported shading textures"):format(elapsed))
        end)
        Time.MeasureTime(function()
            self:ExportDiffuse()
        end, function (elapsed)
            Log.Notice(("[%.4fs] Exported diffuse"):format(elapsed))
        end)
    end)
end
