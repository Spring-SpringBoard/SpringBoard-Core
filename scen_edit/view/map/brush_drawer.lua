BrushDrawer = {}

function BrushDrawer.GetBrushTexture(texturePath, width, height, drawOpts)
    local luaTex = gl.CreateTexture(width, height, {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = true,
    })
    BrushDrawer.UpdateLuaTexture(luaTex, texturePath, width, height, drawOpts)
    return luaTex
end

local drawMethods = {
    color = function(data)
        gl.Color(data[1], data[2], data[3], data[4])
    end,
    rotation = function(data)
        gl.Rotate(data[1], 1, 1)
    end,
    offset = function(data)
        gl.Translate(data[1], data[2], data[3], data[4])
    end,
}

function BrushDrawer.UpdateLuaTexture(luaTex, texturePath, width, height, drawOpts)
    local texFile = ':clr' .. width .. ',' .. height .. ':' .. tostring(texturePath)
    SB.model.textureManager:Blit(texFile, luaTex)
end
