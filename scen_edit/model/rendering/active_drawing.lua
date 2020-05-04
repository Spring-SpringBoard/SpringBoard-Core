-- FIXME: naming sucks..
ActiveDrawing = LCS.class{}

function ActiveDrawing:init()
    self.activeDrawingTextures = {}
end

function ActiveDrawing:SetActiveTexture(originalTextureObj)
    local originalTexture = originalTextureObj.texture
    local activeTexture = self.activeDrawingTextures[originalTexture]
    if activeTexture ~= nil then
        return activeTexture
    end

    activeTexture = gfx.CloneTexture(originalTexture)
    self.activeDrawingTextures[originalTexture] = {
        originalTextureObj = originalTextureObj,
        texture = activeTexture,
        dirty = originalTextureObj.dirty,
    }
    return activeTexture
end

function ActiveDrawing:Reset()
    self.activeDrawingTextures = {}
end

function ActiveDrawing:Get()
    return self.activeDrawingTextures
end
