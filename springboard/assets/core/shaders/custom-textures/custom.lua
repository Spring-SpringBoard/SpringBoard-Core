local dir = Path.ExtractDir(__path__)
local shader = Shaders.Compile({
    vertex = VFS.LoadFile(Path.Join(dir, "custom.vert"), nil, VFS.MOD),
    fragment = VFS.LoadFile(Path.Join(dir, "custom.frag"), nil, VFS.MOD),
    uniformInt = {
        texSplatDistr = 1,
        texSplatTexture = 2,
    },
    uniform = {
        customSamplerSize = { Game.mapSizeX, Game.mapSizeZ },
    },
}, "Custom Map Shader")

local splatDistr = Path.Join(SB.DIRS.ASSETS, "core/brush_patterns/terrain/circle1.png")
splatDistr = gfx.CloneTexture(splatDistr, {
    wrap_s = GL.REPEAT,
    wrap_t = GL.REPEAT
})

local texture1 = Path.Join(dir, "dirt_lowres.png")
texture1 = gfx.CloneTexture(texture1)

local function DrawGroundPreForward()
    gl.Texture(1, splatDistr)
    gl.Texture(2, texture1)
    gl.Texture(1, false)
    gl.Texture(2, false)
end

return {
    shader = shader,
    DrawGroundPreForward = DrawGroundPreForward,
    texture = {
        splatDistr = splatDistr,
        texture1 = texture1
    }
}
