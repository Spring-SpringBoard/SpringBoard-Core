local dir = Path.ExtractDir(__path__)
local minHeight, maxHeight = Spring.GetGroundExtremes()
local shader = Shaders.Compile({
    vertex = VFS.LoadFile(Path.Join(dir, "height_filter.vert")),
    fragment = VFS.LoadFile(Path.Join(dir, "height_filter.frag")),
    uniform = {
        minHeight = minHeight,
        maxHeight = maxHeight,
    },
}, "Height-based shading")

-- Spring.Echo(shader)
-- table.echo(gl.GetActiveUniforms(shader))

return {
    shader = shader,
    uniform = {
        minHeight = minHeight,
        maxHeight = maxHeight,
    }
}
