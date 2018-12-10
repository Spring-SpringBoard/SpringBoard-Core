local dir = Path.ExtractDir(__path__)
local shader = Shaders.Compile({
    vertex = VFS.LoadFile(Path.Join(dir, "fow.vert"), nil, VFS.MOD),
    fragment = VFS.LoadFile(Path.Join(dir, "fow.frag"), nil, VFS.MOD),
    uniformInt = {
        texSampler = 0,
        customSampler = 1,
    },
    uniform = {
        customSamplerSize = { Game.mapSizeX, Game.mapSizeZ },
    },
}, "Custom Map Shader")


local texInfo = gl.TextureInfo("$info_los")
local FOW_TEX = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
    fbo = true,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP_TO_EDGE,
    wrap_t = GL.CLAMP_TO_EDGE,
})

local function Blit(tex1, tex2)
    gl.Blending("add")
    gl.Texture(tex1)
    gl.RenderToTexture(tex2, function()
        gl.TexRect(-1,-1, 1, 1, 0, 0, 1, 1)
    end)
    gl.Texture(false)
end

local function DrawWorld()
    Blit("$info_los", FOW_TEX)
end

local function DrawGroundPreForward()
    gl.Texture(1, FOW_TEX)
end

return {
    shader = shader,
    DrawGroundPreForward = DrawGroundPreForward,
    DrawWorld = DrawWorld,
}
