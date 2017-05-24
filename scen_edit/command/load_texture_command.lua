LoadTextureCommand = AbstractCommand:extends{}
LoadTextureCommand.className = "LoadTextureCommand"

function LoadTextureCommand:init(texturePath)
    self.className = "LoadTextureCommand"
    self.texturePath = texturePath
end

function LoadTextureCommand:execute()
    SCEN_EDIT.delayGL(function()
        local tm = SCEN_EDIT.model.textureManager

        local files = VFS.DirList(self.texturePath)

        if #files == 0 then
            return
        end

        tm:resetMapTextures()
        tm:generateMapTextures()

        local textures = {}
        for _, file in pairs(files) do
            local _, i, j = file:match(".*(texture)-(%d+)-(%d+).png")
            if i == nil or j == nil then
                Log.Error(i, j)
                Log.Error("Texture files names are in incorrect format. Expected \"texture-i-j.png\", got " .. tostring(file))
                return
            end
            table.insert(textures, {path = file, i = tonumber(i), j = tonumber(j)})
        end

        for _, texture in pairs(textures) do
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
