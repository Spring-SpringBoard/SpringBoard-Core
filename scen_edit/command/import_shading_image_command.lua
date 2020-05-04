ImportShadingImageCommand = Command:extends{}
ImportShadingImageCommand.className = "ImportShadingImageCommand"

function ImportShadingImageCommand:init(texType, texturePath)
    self.texType = texType
    self.texturePath = texturePath
end

function LoadShadingTexture(texType, path, fromProject)
    local texObj = SB.model.textureManager.shadingTextures[texType]
    if not texObj then
        Log.Notice(("Creating and enabling new texture type: %s..."):format(tostring(texType)))
        local texInfo = gl.TextureInfo(path)
        local sizeX, sizeY = texInfo.xsize, texInfo.ysize
        SB.model.textureManager:MakeAndEnableMapShadingTexture({
            name = texType,
            sizeX = sizeX,
            sizeY = sizeY,
            texture = path
        })
        return
    end

    local texture = texObj.texture
    gl.Blending("disable")
    gl.RenderToTexture(texture, function()
        gl.Texture(path)
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
        gl.DeleteTexture(path)
    end)
    if texType:find("splat_normals") then
        gl.GenerateMipmap(texture)
    end
    texObj.dirty = not fromProject
end

function ImportShadingImageCommand:execute()
    SB.delayGL(function()
        LoadShadingTexture(self.texType, self.texturePath, false)
    end)
end
