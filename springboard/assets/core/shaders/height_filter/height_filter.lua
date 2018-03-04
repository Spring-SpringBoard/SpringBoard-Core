local dir = Path.ExtractDir(__path__)
local minHeight, maxHeight = Spring.GetGroundExtremes()
local shader = Shaders.Compile({
    vertex = VFS.LoadFile(Path.Join(dir, "height_filter.vert")),
    fragment = VFS.LoadFile(Path.Join(dir, "height_filter.frag")),
    uniform = {
        minHeight = minHeight,
        maxHeight = maxHeight,
    },
    uniformInt = {
        heightmap = 2,
    }
}, "Height-based shading")

-- Spring.Echo(shader)
-- table.echo(gl.GetActiveUniforms(shader))

-- local function DrawGroundPreForward()
--     gl.Texture(2, "$heightmap")
-- end


return {
    shader = shader,
    -- DrawGroundPreForward = DrawGroundPreForward,
    uniform = {
        minHeight = minHeight,
        maxHeight = maxHeight,
    }
}
