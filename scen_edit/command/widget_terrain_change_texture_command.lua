WidgetTerrainChangeTextureCommand = Command:extends{}
WidgetTerrainChangeTextureCommand.className = "WidgetTerrainChangeTextureCommand"

function WidgetTerrainChangeTextureCommand:init(opts)
    self.opts = opts
end

function WidgetTerrainChangeTextureCommand:execute()
    SB.delayGL(function()
        self:SetTexture(self.opts)
    end)
end

-- FIXME: This is unnecessary probably. Confirm with engine code
function CheckGLSL(shader)
    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Log.Error("Shader error!")
        Log.Error(errors)
    end
end

local function rotate(x, y, angle)
    return x * math.cos(angle) - y * math.sin(angle),
           x * math.sin(angle) + y * math.cos(angle)
end

function WidgetTerrainChangeTextureCommand:SetTexture(opts)
    local x, z = opts.x, opts.z
    local size = opts.size

    -- We calculate coordinates so we know x and z extremes
    local patternRot = opts.patternRotation
    local sh = size/2
    -- clockwise coords
    local x1, z1 = rotate(-sh, sh, patternRot)
    local x2, z2 = rotate(sh, sh, patternRot)
    local x3, z3 = rotate(sh, -sh, patternRot)
    local x4, z4 = rotate(-sh, -sh, patternRot)
    x1, z1 = x1 + x + sh, z1 + z + sh
    x2, z2 = x2 + x + sh, z2 + z + sh
    x3, z3 = x3 + x + sh, z3 + z + sh
    x4, z4 = x4 + x + sh, z4 + z + sh
    x = math.min(x1, x2, x3, x4)
    z = math.min(z1, z2, z3, z4)
    size = math.max(x1, x2, x3, x4) - x

    local texSize = SB.model.textureManager.TEXTURE_SIZE
    if opts.paintMode == "void" then
        DrawVoid(opts, x / texSize, z / texSize, size / texSize)
    elseif opts.paintMode == "blur" then
        DrawFilter(opts, x / texSize, z / texSize, size / texSize)
    elseif opts.paintMode == "paint" then
        DrawDiffuse(opts, x / texSize, z / texSize, size / texSize)
        DrawShadingTextures(opts, x, z, size)
    elseif opts.paintMode == "dnts" then
        DrawDNTS(opts, x, z, size)
    else
        Log.Error("Unexpected paint mode: " .. tostring(opts.paintMode))
    end
end

WidgetUndoTerrainChangeTextureCommand = Command:extends{}
WidgetUndoTerrainChangeTextureCommand.className = "WidgetUndoTerrainChangeTextureCommand"

function WidgetUndoTerrainChangeTextureCommand:execute()
    SB.delayGL(function()
        SB.model.textureManager:PopStack()
    end)
end

WidgetTerrainChangeTexturePushStackCommand = Command:extends{}
WidgetTerrainChangeTexturePushStackCommand.className = "WidgetTerrainChangeTexturePushStackCommand"

function WidgetTerrainChangeTexturePushStackCommand:execute()
    SB.delayGL(function()
        SB.model.textureManager:PushStack()
    end)
end
