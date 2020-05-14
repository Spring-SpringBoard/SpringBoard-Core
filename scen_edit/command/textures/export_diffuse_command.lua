ExportDiffuseCommand = Command:extends{}
ExportDiffuseCommand.className = "ExportDiffuseCommand"

function ExportDiffuseCommand:init(path)
    self.path = path
end

local function ExportDiffuse(path)
    if VFS.FileExists(path, VFS.RAW) then
        Log.Notice("Removing the existing texture")
        os.remove(path)
    end

    Log.Notice("Saving the texture to " .. path .. "...")
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
    for i = 0, sizeX do
        for j = 0, sizeZ do
            local mapTextureObj = SB.model.textureManager.mapFBOTextures[i][j]

            local mapTexture = mapTextureObj.texture
            local mapFBO = gl.CreateFBO({
                color0 = mapTexture
            })
            gl.BlitFBO(
                mapFBO, 0, 0, texSize, texSize,
                totalMapFBO,

                i * texSize,
                (sizeZ - j) * texSize,
                (i + 1) * texSize,
                (sizeZ - j - 1) * texSize)
            gl.DeleteFBO(mapFBO)
        end
    end
    gl.RenderToTexture(totalMapTexture, gl.SaveImage, 0, 0, Game.mapSizeX, Game.mapSizeZ, path)
    gl.DeleteTexture(totalMapTexture)
    -- FIXME: probably not needed -.-
    gl.Flush()
end

function ExportDiffuseCommand:execute()
    return SB.delayGL(function()
        Spring.CreateDir(Path.GetParentDir(self.path))

        Time.MeasureTime(function()
            Spring.ClearWatchDogTimer(nil, true)
            ExportDiffuse(self.path)
            Spring.ClearWatchDogTimer(nil, false)
        end, function (elapsed)
            Log.Notice(("[%.4fs] Exported diffuse"):format(elapsed))

            -- TODO: Cleanup
            -- if SB.editors["terrainSettings"] ~= nil then
            --     SB.editors["terrainSettings"]:UpdateCompilePaths(Path.GetParentDir(self.path))
            -- end

        end)
    end)
end
