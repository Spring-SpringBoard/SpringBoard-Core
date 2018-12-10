local dir = Path.ExtractDir(__path__)
local shader = Shaders.Compile({
    vertex = VFS.LoadFile(Path.Join(dir, "vertex.glsl"), nil, VFS.MOD),
    fragment = VFS.LoadFile(Path.Join(dir, "fragment.glsl"), nil, VFS.MOD),
    uniformInt = {
        texSampler = 0,
    },
}, "Basic Map Shader")

return {
    shader = shader
}
