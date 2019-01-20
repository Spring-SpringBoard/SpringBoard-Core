local filterShader

local function getFilterShader()
    if filterShader == nil then
        local shaderFragStr = VFS.LoadFile("shaders/map_blur_drawing.glsl", nil, VFS.MOD)
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
                patternTexture = 1,
            },
        }

        local shader = Shaders.Compile(shaderTemplate, "blur")
        filterShader = {
            shader = shader,
            uniforms = {
                patternRotationID = gl.GetUniformLocation(shader, "patternRotation"),
                strengthID = gl.GetUniformLocation(shader, "strength"),
                kernelID = gl.GetUniformLocation(shader, "kernel"),
            },
        }
    end

    return filterShader
end

function DrawFilter(opts, x, z, size)
    local textures = SB.model.textureManager:getMapTextures(x, z, x + size, z + size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = gfx:MakeMapTextureCopies(textures)

    local shaderObj = getFilterShader()
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    if opts.kernelMode == "blur" then
        gl.UniformMatrix(uniforms.kernelID, 0.0625, 0.125, 0.0625, 0.125, 0.25, 0.125, 0.0625, 0.125, 0.0625)
    elseif opts.kernelMode == "bottom_sobel" then
        gl.UniformMatrix(uniforms.kernelID, -1, -2, -1, 0, 0, 0, 1, 2, 1)
    elseif opts.kernelMode == "emboss" then
        gl.UniformMatrix(uniforms.kernelID, -2, -1, 0, -1, 1, 1, 0, 1, 2)
    elseif opts.kernelMode == "left_sobel" then
        gl.UniformMatrix(uniforms.kernelID, 1, 0, -1, 2, 0, -2, 1, 0, -1)
    elseif opts.kernelMode == "outline" then
        gl.UniformMatrix(uniforms.kernelID, -1, -1, -1, -1, 8, -1, -1, -1, -1)
    elseif opts.kernelMode == "right_sobel" then
        gl.UniformMatrix(uniforms.kernelID, -1, 0, 1, -2, 0, 2, -1, 0, 1)
    elseif opts.kernelMode == "sharpen" then
        gl.UniformMatrix(uniforms.kernelID, 0, -1, 0, -1, 5, -1, 0, -1, 0)
    elseif opts.kernelMode == "top sobel" then
        gl.UniformMatrix(uniforms.kernelID, 1, 2, 1, 0, 0, 0, -1, -2, -1)
    end

    gl.Uniform(uniforms.strengthID, opts.strength)
    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))
    gl.Uniform(uniforms.patternRotationID, opts.patternRotation)

    local tCoord = __GenerateTextureCoords(x, z, size, size, opts)
    for i, v in pairs(textures) do
        local renderTexture = v.renderTexture
        local mapTexture = renderTexture.texture
        renderTexture.dirty = true
        local mCoord, vCoord = __GenerateMapCoords(v.x, v.y, size, size)

        gl.Texture(0, tmps[i])
        gl.RenderToTexture(mapTexture, ApplyTexture, mCoord, tCoord, vCoord)
    end
    CheckGLSL(shader)

    -- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)
end