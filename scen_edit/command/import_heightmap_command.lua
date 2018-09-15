ImportHeightmapCommand = Command:extends{}
ImportHeightmapCommand.className = "ImportHeightmapCommand"

function ImportHeightmapCommand:init(heightmapImage, maxHeight, minHeight)
    self.className = "ImportHeightmapCommand"
    self.heightmapImagePath = heightmapImage
    self.maxHeight = maxHeight
    self.minHeight = minHeight
end

function ImportHeightmapCommand:execute()
    SB.delayGL(function()
        if not VFS.FileExists(self.heightmapImagePath) then
            Log.Error("Missing heightmap file: " .. tostring(self.heightmapImagePath))
            return
        end

        Log.Debug("Importing heightmap..")
        local heightmapTexture = gl.CreateTexture(
            Game.mapSizeX / Game.squareSize + 1,
            Game.mapSizeZ / Game.squareSize + 1, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })

        local texInfo = gl.TextureInfo(heightmapTexture)
        local res

        gl.Blending("disable")
        gl.Texture(self.heightmapImagePath)
        gl.RenderToTexture(heightmapTexture, function()
            gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
            res = gl.ReadPixels(0, 0, texInfo.xsize, texInfo.ysize)
        end)
        gl.Texture(false)
        gl.DeleteTexture(self.heightmapImagePath)
        gl.DeleteTexture(heightmapTexture)

        local greyscale = {}
        local h = 0
        for i, row in ipairs(res) do
            greyscale[i] = {}
            for j, point in ipairs(row) do
                h = (point[1] + point[2] + point[3]) / 3 * point[4]
                greyscale[i][j] = self.minHeight + h * (self.maxHeight - self.minHeight)
            end
        end
        SB.commandManager:execute(ImportHeightmapCommandSynced(greyscale))
    end)
end

ImportHeightmapCommandSynced = Command:extends{}
ImportHeightmapCommandSynced.className = "ImportHeightmapCommandSynced"

function ImportHeightmapCommandSynced:init(greyscale)
    self.className = "ImportHeightmapCommandSynced"
    self.greyscale = greyscale
end

function ImportHeightmapCommandSynced:execute()
    Spring.SetHeightMapFunc(function()
        for x = 0, Game.mapSizeX, Game.squareSize do
            for z = 0, Game.mapSizeZ, Game.squareSize do
                local column = self.greyscale[x / Game.squareSize + 1]
                Spring.SetHeightMap(x, z, column[z / Game.squareSize + 1])--column[z / Game.squareSize + 1])
            end
        end
    end)
end
