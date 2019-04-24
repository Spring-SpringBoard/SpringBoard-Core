local heightShader

local function getHeightShader()
    if heightShader == nil then
        local shaderFragStr = VFS.LoadFile("shaders/map_height_drawing.glsl", nil, VFS.MOD)
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
                patternTexture = 1,
                heightTexture = 2,
            },
        }

        local shader = Shaders.Compile(shaderTemplate, "height")
        heightShader = {
            shader = shader,
            uniforms = {
                patternRotationID = gl.GetUniformLocation(shader, "patternRotation"),
                strengthID = gl.GetUniformLocation(shader, "strength"),
                minHeightID = gl.GetUniformLocation(shader, "minHeight"),
                maxHeightID = gl.GetUniformLocation(shader, "maxHeight"),
            },
        }
    end

    return heightShader
end

local function DrawQuads2(mCoord, tCoord, vCoord, hCoord)
    gl.MultiTexCoord(0, mCoord[1], mCoord[2])
    gl.MultiTexCoord(1, 0, 0)
    gl.MultiTexCoord(2, tCoord[1], tCoord[2])
    gl.MultiTexCoord(3, hCoord[1], hCoord[2])
    gl.Vertex(vCoord[1], vCoord[2])

    gl.MultiTexCoord(0, mCoord[3], mCoord[4])
    gl.MultiTexCoord(1, 0, 1)
    gl.MultiTexCoord(2, tCoord[3], tCoord[4])
    gl.MultiTexCoord(3, hCoord[3], hCoord[4])
    gl.Vertex(vCoord[3], vCoord[4])

    gl.MultiTexCoord(0, mCoord[5], mCoord[6])
    gl.MultiTexCoord(1, 1, 1)
    gl.MultiTexCoord(2, tCoord[5], tCoord[6])
    gl.MultiTexCoord(3, hCoord[5], hCoord[6])
    gl.Vertex(vCoord[5], vCoord[6])

    gl.MultiTexCoord(0, mCoord[7], mCoord[8])
    gl.MultiTexCoord(1, 1, 0)
    gl.MultiTexCoord(2, tCoord[7], tCoord[8])
    gl.MultiTexCoord(3, hCoord[7], hCoord[8])
    gl.Vertex(vCoord[7], vCoord[8])
end

function ApplyTexture2(mCoord, tCoord, vCoord, hCoord)
    -- TODO: move all this to a vertex shader?
    gl.BeginEnd(GL.QUADS, DrawQuads2, mCoord, tCoord, vCoord, hCoord)
end

function DrawHeight(opts, x, z, size)
    local textures = SB.model.textureManager:getMapTextures(x, z, x + size, z + size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = gfx:MakeMapTextureCopies(textures)

    local shaderObj = getHeightShader()
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    gl.Uniform(uniforms.strengthID, opts.strength)
    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))
    gl.Uniform(uniforms.patternRotationID, opts.patternRotation)
    gl.Texture(2, "$heightmap")


    local textureSize = SB.model.textureManager.TEXTURE_SIZE
    local i1 = math.max(0, math.floor(x))
    local i2 = math.min(math.floor(Game.mapSizeX / textureSize),
                        math.floor(x + size))
    local j1 = math.max(0, math.floor(z))
    local j2 = math.min(math.floor(Game.mapSizeZ / textureSize),
                        math.floor(z + size))
    local idxs = {}
    for i = i1, i2 do
        for j = j1, j2 do
            table.insert(idxs, {i, j})
        end
    end
    local factor = SB.model.textureManager.TEXTURE_SIZE / Game.mapSizeX

    local minHeight, maxHeight = Spring.GetGroundExtremes()
    gl.Uniform(uniforms.minHeightID, minHeight)
    gl.Uniform(uniforms.maxHeightID, maxHeight)

    local tCoord = __GenerateTextureCoords(x, z, size, size, opts)
    for i, v in pairs(textures) do
        local renderTexture = v.renderTexture
        local mapTexture = renderTexture.texture
        renderTexture.dirty = true
        local mCoord, vCoord = __GenerateMapCoords(v.x, v.y, size, size)

        local idx = idxs[i]
        local top    = (idx[1] + v.x) * factor
        local bottom = (idx[1] + v.x + size) * factor
        local left   = (idx[2] + v.y) * factor
        local right  = (idx[2] + v.y + size) * factor
        local hCoord = {
            top, left,
            top, right,
            bottom, right,
            bottom, left
        }

        gl.Texture(0, tmps[i])
        gl.RenderToTexture(mapTexture, ApplyTexture2, mCoord, tCoord, vCoord, hCoord)
    end
    CheckGLSL(shader)

    -- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.Texture(2, false)
    gl.UseShader(0)
end