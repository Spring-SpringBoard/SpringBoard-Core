ExportShadingTexturesCommand = Command:extends{}
ExportShadingTexturesCommand.className = "ExportShadingTexturesCommand"

function ExportShadingTexturesCommand:init(path)
    self.path = path
end

local function ExportShadingTextures(path)
    for texType, shadingTexObj in pairs(SB.model.textureManager.shadingTextures) do
        SB.WriteShadingTextureToFile(texType, Path.Join(path, texType .. ".png"))
    end
end

function ExportShadingTexturesCommand:execute()
    SB.delayGL(function()
        Spring.CreateDir(Path.GetParentDir(self.path))

        Time.MeasureTime(function()
            Spring.ClearWatchDogTimer(nil, true)
            ExportShadingTextures(self.path)
            Spring.ClearWatchDogTimer(nil, false)
        end, function (elapsed)
            Log.Notice(("[%.4fs] Exported shading textures"):format(elapsed))
        end)
    end)
end