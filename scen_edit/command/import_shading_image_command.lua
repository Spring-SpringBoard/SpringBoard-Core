ImportShadingImageCommand = NativeCommand:extends{}
ImportShadingImageCommand.className = "ImportShadingImageCommand"

function ImportShadingImageCommand:init(texType, texturePath)
    self.texType = texType
    self.texturePath = texturePath
end
