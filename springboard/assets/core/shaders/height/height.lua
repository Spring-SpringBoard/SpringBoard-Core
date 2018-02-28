local dir = Path.ExtractDir(__path__)
local shader = Shaders.Compile({
    vertex = VFS.LoadFile(Path.Join(dir, "height.vert")),
    fragment = VFS.LoadFile(Path.Join(dir, "height.frag")),
    uniformInt = {
        customSampler = 1,
    },
    uniform = {
        customSamplerSize = { Game.mapSizeX, Game.mapSizeZ },
    },
}, "Custom Height Map Shader")

local DIRT_TEXTURE = Path.Join(dir, "dirt_lowres.png")

local function DrawGroundPreForward()
    gl.Texture(1, DIRT_TEXTURE)
end

return {
    shader = shader,
    DrawGroundPreForward = DrawGroundPreForward
}
