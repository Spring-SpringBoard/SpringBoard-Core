Graphics = LCS.class{}

SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'gfx'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'gfx/draw'))

function Graphics:init()
    self:__InitTempTextures()
end

function Graphics.Blit(tex1, tex2)
    gl.Blending("disable")
    gl.Texture(tex1)
    gl.RenderToTexture(tex2, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
    end)
    gl.Texture(false)
end

function Graphics.CloneTexture(texture, opt)
    local texInfo = gl.TextureInfo(texture)
    local params = {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        wrap_s = GL.CLAMP_TO_EDGE,
        wrap_t = GL.CLAMP_TO_EDGE,
        fbo = true,
    }
    if opt ~= nil then
        for k, v in pairs(opt) do
            params[k] = v
        end
    end
    local cloned = gl.CreateTexture(texInfo.xsize, texInfo.ysize, params)
    Graphics.Blit(texture, cloned)
    return cloned
end