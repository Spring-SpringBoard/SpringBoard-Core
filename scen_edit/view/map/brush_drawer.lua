BrushDrawer = {}

function BrushDrawer.GetBrushTexture(width, height)
    local luaTex = gl.CreateTexture(width, height, {
        border = false,
        min_filter = GL.LINEAR,
        mag_filter = GL.LINEAR,
        fbo = true,
    })
    return luaTex
end

function BrushDrawer.UpdateLuaTexture(luaTex, texturePath, width, height, drawOpts)
    local texFile = ':lr' .. width .. ',' .. height .. ':' .. tostring(texturePath)
    if texturePath ~= nil and texturePath:sub(1, 1) == "!" then
        texFile = texturePath
    end

    gl.MatrixMode(GL.TEXTURE)

    -- gl.PushAttrib(GL.ALL_ATTRIB_BITS)
    -- gl.PushMatrix()

    if drawOpts.color then
        gl.Color(drawOpts.color[1], drawOpts.color[2], drawOpts.color[3], drawOpts.color[4])
    end
    gl.LoadIdentity()
    if drawOpts.offset then
        gl.Translate(drawOpts.offset[1], drawOpts.offset[2], 0.0)
    end
    if drawOpts.rotation then
        gl.Translate(0.5,0.5,0.0)
        gl.Rotate(drawOpts.rotation, 0.0, 0.0, 1.0)
        gl.Translate(-0.5,-0.5,0.0)
    end
    if drawOpts.scale then
        gl.Scale(drawOpts.scale, drawOpts.scale, drawOpts.scale)
    end
    SB.model.textureManager:Blit(texFile, luaTex)

    -- gl.PopMatrix()
    -- gl.PopAttrib(GL.ALL_ATTRIB_BITS)

    gl.MatrixMode(GL.MODELVIEW)
end
