LoadTextureCommand = Command:extends{}
LoadTextureCommand.className = "LoadTextureCommand"

function LoadTextureCommand:init(texturePath)
    self.className = "LoadTextureCommand"
    self.texturePath = texturePath
end

function LoadTextureCommand:execute()
    SB.delayGL(function()
        local tm = SB.model.textureManager

        local files = VFS.DirList(self.texturePath)

        if #files == 0 then
            return
        end

        tm:resetMapTextures()
        tm:generateMapTextures()

        local textures = {}
        for _, file in pairs(files) do
            local _, i, j = file:match(".*(texture)-(%d+)-(%d+).png")
            if i ~= nil and j ~= nil then
                table.insert(textures, {
                        path = file,
                        i = tonumber(i),
                        j = tonumber(j)
                    })
            else
                -- Log.Error(i, j)
                -- Log.Error("Texture files names are in incorrect format. Expected \"texture-i-j.png\", got " .. tostring(file))
                -- return
            end
        end

        for texType, _ in pairs(SB.model.textureManager.shadingTextures) do
            local texPath = Path.Join(self.texturePath, "shading-" .. texType .. ".png")
            if VFS.FileExists(texPath) then
                LoadShadingTexture(texType, texPath)
            end
        end

        for _, texture in pairs(textures) do
            Spring.ClearWatchDogTimer()

            local fboTextureObj = tm.mapFBOTextures[texture.i][texture.j]
            gl.RenderToTexture(fboTextureObj.texture, function()
                gl.Texture(texture.path)
                gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
                gl.DeleteTexture(texture.path)
            end)
        end
        gl.Texture(false)
    end)
end
