local ImportHeightmapWithLauncher

ImportHeightmapCommand = Command:extends{}
ImportHeightmapCommand.className = "ImportHeightmapCommand"

function ImportHeightmapCommand:init(heightmapImage, minHeight, maxHeight)
    self.heightmapImagePath = heightmapImage
    self.minHeight = minHeight
    self.maxHeight = maxHeight
end

function ImportHeightmapCommand:execute()
    if not VFS.FileExists(self.heightmapImagePath, VFS.RAW) then
        Log.Error("Missing heightmap file: " .. tostring(self.heightmapImagePath))
        return
    end

    local tempDir = SB.CreateTemporaryDir("import-heightmap")
    local outputPath = Path.Join(tempDir, "heightmap.data")
    ImportHeightmapWithLauncher(self.heightmapImagePath, outputPath, self.minHeight, self.maxHeight):next(function()
        local cmd = LoadMapCommand(VFS.LoadFile(outputPath, VFS.RAW))
        SB.commandManager:execute(cmd)
        SB.RemoveDirRecursively(tempDir)
    end)
end

ImportHeightmapWithLauncher = function(inPath, outPath, minHeight, maxHeight)
    return WG.Connector.Send("ImportSBHeightmap", {
        inPath = inPath,
        outPath = outPath,
        min = minHeight,
        max = maxHeight,
        width = Game.mapSizeX / Game.squareSize + 1,
        height = Game.mapSizeZ / Game.squareSize + 1
    }, {
        waitForResult = true
    })
end

-- LEGACY Import with SPring

-- function ImportHeightmapCommand:execute()
--     SB.delayGL(function()
--         if not VFS.FileExists(self.heightmapImagePath) then
--             Log.Error("Missing heightmap file: " .. tostring(self.heightmapImagePath))
--             return
--         end

--         Log.Debug("Importing heightmap..")
--         local heightmapTexture = gl.CreateTexture(
--             Game.mapSizeX / Game.squareSize + 1,
--             Game.mapSizeZ / Game.squareSize + 1, {
--             border = false,
--             min_filter = GL.LINEAR,
--             mag_filter = GL.LINEAR,
--             wrap_s = GL.CLAMP_TO_EDGE,
--             wrap_t = GL.CLAMP_TO_EDGE,
--             fbo = true,
--         })

--         local texInfo = gl.TextureInfo(heightmapTexture)
--         local res

--         gl.Blending("disable")
--         gl.Texture(self.heightmapImagePath)
--         gl.RenderToTexture(heightmapTexture, function()
--             gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
--             res = gl.ReadPixels(0, 0, texInfo.xsize, texInfo.ysize)
--         end)
--         gl.Texture(false)
--         gl.DeleteTexture(self.heightmapImagePath)
--         gl.DeleteTexture(heightmapTexture)

--         local greyscale = {}
--         for i, row in ipairs(res) do
--             greyscale[i] = {}
--             for j, point in ipairs(row) do
--                 local h = (point[1] + point[2] + point[3]) / 3 * point[4]
--                 greyscale[i][j] = self.minHeight + h * (self.maxHeight - self.minHeight)
--             end
--         end
--         SB.commandManager:execute(ImportHeightmapCommandSynced(greyscale))
--     end)
-- end
-- ImportHeightmapCommandSynced = Command:extends{}
-- ImportHeightmapCommandSynced.className = "ImportHeightmapCommandSynced"

-- function ImportHeightmapCommandSynced:init(greyscale)
--     self.greyscale = greyscale
-- end

-- function ImportHeightmapCommandSynced:execute()
--     Spring.SetHeightMapFunc(function()
--         for x = 0, Game.mapSizeX, Game.squareSize do
--             for z = 0, Game.mapSizeZ, Game.squareSize do
--                 local column = self.greyscale[x / Game.squareSize + 1]
--                 Spring.SetHeightMap(x, z, column[z / Game.squareSize + 1])--column[z / Game.squareSize + 1])
--             end
--         end
--     end)
-- end
