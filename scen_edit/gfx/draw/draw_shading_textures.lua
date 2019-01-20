function DrawShadingTextures(opts, x, z, size)
    local tmpMap = {}
    local wantedCopies = {}
    for texType, shadingTexObj in pairs(SB.model.textureManager.shadingTextures) do
        if opts.brushTexture[texType] and opts[texType .. "Enabled"] then
            SB.model.textureManager:BackupShadingTexture(texType)
            table.insert(wantedCopies, shadingTexObj.texture)
            tmpMap[#wantedCopies] = texType
        end
    end

    local tmps = {}
    for i, tmp in ipairs(gfx:MakeTextureCopies(wantedCopies)) do
        tmps[tmpMap[i]] = tmp
    end

    local shaderObj = getPenShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    gl.Uniform(uniforms.strengthID, opts.strength)
    gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
    gl.Uniform(uniforms.featureFactorID, opts.featureFactor)
    opts.diffuseColor[4] = 1.0
    gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))
    --gl.Uniform(uniforms.voidFactorID, opts.voidFactor)
    gl.Uniform(uniforms.patternRotationID, opts.patternRotation)

    local sizeX  = size / Game.mapSizeX
    local sizeZ  = size / Game.mapSizeZ
    -- local mx     = x    / Game.mapSizeX
    -- local mz     = z    / Game.mapSizeZ
    local ts = SB.model.textureManager.TEXTURE_SIZE
    local tCoord = __GenerateTextureCoords(x / ts, z / ts, size / ts, size / ts, opts)

    local mCoord, vCoord = __GenerateMapCoords(x / Game.mapSizeX, z / Game.mapSizeZ, sizeX, sizeZ)

    gl.Uniform(uniforms.x1ID, mCoord[1])
    gl.Uniform(uniforms.x2ID, mCoord[5])
    gl.Uniform(uniforms.z1ID, mCoord[2])
    gl.Uniform(uniforms.z2ID, mCoord[4])

    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))
    for texType, shadingTexObj in pairs(SB.model.textureManager.shadingTextures) do
        if opts.brushTexture[texType] and opts[texType .. "Enabled"] then
            local shadingTex = shadingTexObj.texture
            shadingTexObj.dirty = true
            gl.Texture(2, SB.model.textureManager:GetTexture(opts.brushTexture[texType]))
            gl.Texture(0, tmps[texType])
            gl.RenderToTexture(shadingTex, ApplyTexture, mCoord, tCoord, vCoord)

            CheckGLSL(shader)
        end
    end

    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.Texture(2, false)
    gl.UseShader(0)
end
