ImportHeightmapCommand = AbstractCommand:extends{}
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

        Log.Debug("scened", LOG.DEBUG, "Importing heightmap..")
        local heightmapTexture = gl.CreateTexture(Game.mapSizeX / Game.squareSize + 1, Game.mapSizeZ / Game.squareSize + 1, {
            border = false,
            min_filter = GL.NEAREST,
            mag_filter = GL.NEAREST,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })

        local texInfo = gl.TextureInfo(heightmapTexture)
        local w, h = texInfo.xsize, texInfo.ysize
        local res

		gl.Blending("disable")
        gl.RenderToTexture(heightmapTexture, function()
            gl.Texture(self.heightmapImagePath)
            gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
            res = gl.ReadPixels(0, 0, w, h)
            gl.DeleteTexture(self.heightmapImagePath)
        end)

        local greyscale = {}
        for i, row in pairs(res) do
            greyscale[i] = {}
            for j, point in pairs(row) do
                greyscale[i][j] = (point[1] + point[2] + point[3]) / 3 * point[4]
                greyscale[i][j] = self.minHeight + greyscale[i][j] * (self.maxHeight - self.minHeight)
            end
        end

        SB.commandManager:execute(ImportHeightmapCommandSynced(greyscale))
    end)
end

ImportHeightmapCommandSynced = AbstractCommand:extends{}
ImportHeightmapCommandSynced.className = "ImportHeightmapCommandSynced"

function ImportHeightmapCommandSynced:init(greyscale)
    self.className = "ImportHeightmapCommandSynced"
    self.greyscale = greyscale
end

function ImportHeightmapCommandSynced:execute()
    Spring.SetHeightMapFunc(function()
        for z = 0, Game.mapSizeZ, Game.squareSize do
            for x = 0, Game.mapSizeX, Game.squareSize do
                local column = self.greyscale[z / Game.squareSize + 1]
                Spring.SetHeightMap(x, z, column[x / Game.squareSize + 1])
            end
        end
    end)
end
