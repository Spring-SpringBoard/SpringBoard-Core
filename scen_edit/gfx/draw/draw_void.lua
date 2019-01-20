local voidShader

local function getVoidShader()
    if voidShader == nil then
        local shaderFragStr = VFS.LoadFile("shaders/void_drawing.glsl", nil, VFS.MOD)
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
                patternTexture = 1,
            },
        }

        local shader = Shaders.Compile(shaderTemplate, "void")
        voidShader = {
            shader = shader,
            uniforms = {
                x1ID = gl.GetUniformLocation(shader, "x1"),
                x2ID = gl.GetUniformLocation(shader, "x2"),
                z1ID = gl.GetUniformLocation(shader, "z1"),
                z2ID = gl.GetUniformLocation(shader, "z2"),
                patternRotationID = gl.GetUniformLocation(shader, "patternRotation"),
                voidFactorID = gl.GetUniformLocation(shader, "voidFactor"),
            },
        }
    end

    return voidShader
end

function DrawVoid(opts, x, z, size)
    local textures = SB.model.textureManager:getMapTextures(x, z, x + size, z + size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = gfx:MakeMapTextureCopies(textures)

    local shaderObj = getVoidShader()
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    gl.Uniform(uniforms.voidFactorID, opts.voidFactor)
    gl.Uniform(uniforms.patternRotationID, opts.patternRotation)

    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))

    local tCoord = __GenerateTextureCoords(x, z, size, size, opts)
    for i, v in ipairs(textures) do
        local renderTexture = v.renderTexture
        local mapTexture = renderTexture.texture
        renderTexture.dirty = true
        local mCoord, vCoord = __GenerateMapCoords(v.x, v.y, size, size)

        gl.Uniform(uniforms.x1ID, mCoord[1])
        gl.Uniform(uniforms.x2ID, mCoord[5])
        gl.Uniform(uniforms.z1ID, mCoord[2])
        gl.Uniform(uniforms.z2ID, mCoord[4])

        gl.Texture(0, tmps[i])
        gl.RenderToTexture(mapTexture, ApplyTexture, mCoord, tCoord, vCoord)
    end
    CheckGLSL(shader)

    -- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)
end