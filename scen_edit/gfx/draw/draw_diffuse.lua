function DrawDiffuse(opts, x, z, size)
    if not opts["diffuseEnabled"] or not opts.brushTexture.diffuse then
        return
    end

    local textures = SB.model.textureManager:getMapTextures(x, z, x + size, z + size)
    local tmps = gfx:MakeMapTextureCopies(textures)

    local shaderObj = getPenShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))
    gl.Texture(2, SB.model.textureManager:GetTexture(opts.brushTexture.diffuse))

    gl.Uniform(uniforms.strengthID, opts.strength)
    gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
    gl.Uniform(uniforms.featureFactorID, opts.featureFactor)
    opts.diffuseColor[4] = 1.0
    gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))
    --gl.Uniform(uniforms.voidFactorID, opts.voidFactor)
    gl.Uniform(uniforms.patternRotationID, opts.patternRotation)

    local tCoord = __GenerateTextureCoords(x, z, size, size, opts)
    for i, v in pairs(textures) do
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

    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.Texture(2, false)
    gl.UseShader(0)
end