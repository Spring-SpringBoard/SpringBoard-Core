local dir = Path.ExtractDir(__path__)
local shader = Shaders.Compile({
    vertex = VFS.LoadFile(Path.Join(dir, "custom.vert")),
    fragment = VFS.LoadFile(Path.Join(dir, "custom.frag")),
    uniformInt = {
        customSampler = 1,
    },
    uniform = {
        customSamplerSize = { Game.mapSizeX, Game.mapSizeZ },
    },
}, "Custom Map Shader")

local DIRT_TEXTURE = Path.Join(dir, "dirt_lowres.png")

local function DrawGroundPreForward()
    gl.Texture(1, DIRT_TEXTURE)
end

return {
    shader = shader,
    DrawGroundPreForward = DrawGroundPreForward
}
