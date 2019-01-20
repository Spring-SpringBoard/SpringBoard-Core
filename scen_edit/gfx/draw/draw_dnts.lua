local dntsShader

function getDNTSShader()
    if dntsShader == nil then
        local shaderFragStr = VFS.LoadFile("shaders/dnts_drawing.glsl", nil, VFS.MOD)
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
                patternTexture = 1,
            },
        }

        local shader = Shaders.Compile(shaderTemplate, "dnts")
        dntsShader = {
            shader = shader,
            uniforms = {
                x1ID = gl.GetUniformLocation(shader, "x1"),
                x2ID = gl.GetUniformLocation(shader, "x2"),
                z1ID = gl.GetUniformLocation(shader, "z1"),
                z2ID = gl.GetUniformLocation(shader, "z2"),
                patternRotationID = gl.GetUniformLocation(shader, "patternRotation"),
                strengthID = gl.GetUniformLocation(shader, "strength"),
                colorIndexID = gl.GetUniformLocation(shader, "colorIndex"),
                exclusiveID = gl.GetUniformLocation(shader, "exclusive"),
                valueID = gl.GetUniformLocation(shader, "value"),
            },
        }
    end

    return dntsShader
end

-- TODO: Generalize
local function PushUndoStack(texType)
    SB.model.textureManager:BackupShadingTexture(texType)
end

local function SetCustomShaderUniforms(uniforms, opts)
    gl.Uniform(uniforms.strengthID, opts.strength)
    gl.UniformInt(uniforms.colorIndexID, opts.colorIndex)
    gl.UniformInt(uniforms.exclusiveID, opts.exclusive)
    gl.Uniform(uniforms.valueID, opts.value)
    gl.Uniform(uniforms.patternRotationID, opts.patternRotation)
end

function DrawDNTS(opts, x, z, size)
    local texType = "splat_distr"
    local shadingTexObj = SB.model.textureManager.shadingTextures[texType]
    PushUndoStack(texType)

    shadingTexObj.dirty = true
    local shadingTex = shadingTexObj.texture
    local originalTex = gfx:MakeTextureCopies({shadingTexObj.texture})[1]

    local shaderObj = getDNTSShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    local sizeX  = size / Game.mapSizeX
    local sizeZ  = size / Game.mapSizeZ
    local mx     = x    / Game.mapSizeX
    local mz     = z    / Game.mapSizeZ

    gl.Blending("enable")
    gl.UseShader(shader)

    SetCustomShaderUniforms(uniforms, opts)

    local mCoord, vCoord = __GenerateMapCoords(mx, mz, sizeX, sizeZ)

    gl.Uniform(uniforms.x1ID, mCoord[1])
    gl.Uniform(uniforms.x2ID, mCoord[5])
    gl.Uniform(uniforms.z1ID, mCoord[2])
    gl.Uniform(uniforms.z2ID, mCoord[4])

    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))
    gl.Texture(0, originalTex)
    --gl.RenderToTexture(shadingTex, ApplyTexture, mCoord, tCoord, vCoord)
    gl.RenderToTexture(shadingTex, ApplyDNTSTexture, mCoord, vCoord)

    CheckGLSL(shader)

    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)
end