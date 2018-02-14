local dir = Path.ExtractDir(__path__)
local shader = Shaders.Compile({
    vertex = VFS.LoadFile(Path.Join(dir, "vertex.glsl")),
    fragment = VFS.LoadFile(Path.Join(dir, "fragment.glsl")),
    uniformInt = {
        texSampler = 0,
    },
}, "Basic Map Shader")

return {
    shader = shader
}
