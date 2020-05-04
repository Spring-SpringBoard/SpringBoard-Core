local dir = Path.ExtractDir(__path__)
local shader = Shaders.CompileObject({
    vertex = VFS.LoadFile(Path.Join(dir, "height.vert"), nil, VFS.MOD),
    fragment = VFS.LoadFile(Path.Join(dir, "height.frag"), nil, VFS.MOD),
    uniformInt = {
        customSampler = 1,
    },
    uniform = {
        customSamplerSize = { Game.mapSizeX, Game.mapSizeZ },
        time = 0,
    },
}, "Custom Height Map Shader")

-- gl.Uniform(shader.uniform.customSampler)

local texture = Path.Join(SB.DIRS.ASSETS, "core/brush_patterns/terrain/circle1.png")
texture = gfx.CloneTexture(texture)

local function DrawGroundPreForward()
    gl.Texture(1, texture)
    gl.Uniform(shader.uniforms.time.id, os.clock())
    gl.Texture(1, false)
end

return {
    shader = shader.id,
    DrawGroundPreForward = DrawGroundPreForward,
    texture = {
        texture = texture
    }
}
