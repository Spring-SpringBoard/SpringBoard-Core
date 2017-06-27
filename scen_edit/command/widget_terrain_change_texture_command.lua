WidgetTerrainChangeTextureCommand = Command:extends{}
WidgetTerrainChangeTextureCommand.className = "WidgetTerrainChangeTextureCommand"

function WidgetTerrainChangeTextureCommand:init(opts)
    self.className = "WidgetTerrainChangeTextureCommand"
    self.opts = opts
end

function WidgetTerrainChangeTextureCommand:execute()
    SB.delayGL(function()
        self:SetTexture(self.opts)
    end)
end


local function _InitShaders()
    if shaders == nil then
        shaders = {
            diffuse = {},
            void = nil,
            blur = nil,
            dnts = nil,
        }
    end
end

function getPenShader(mode)
    _InitShaders()
    if shaders.diffuse[mode] == nil then
        local penBlenders = {
            --'from'
            --// 2010 Kevin Bjorke http://www.botzilla.com
            --// Uses Processing & the GLGraphics library
            ["Normal"] = [[mix(color,mapColor,color.a);]],

            ["Add"] = [[mix((mapColor+color),mapColor,color.a);]],

            ["ColorBurn"] = [[mix(1.0-(1.0-mapColor)/color,mapColor,color.a);]],

            ["ColorDodge"] = [[mix(mapColor/(1.0-color),mapColor,color.a);]],

            ["Color"] = [[mix(sqrt(dot(mapColor.rgb,mapColor.rgb)) * normalize(color),mapColor,color.a);]],

            ["Darken"] = [[mix(min(mapColor,color),mapColor,color.a);]],

            ["Difference"] = [[mix(abs(color-mapColor),mapColor,color.a);]],

            ["Exclusion"] = [[mix(color+mapColor-(2.0*color*mapColor),mapColor,color.a);]],

            ["HardLight"] = [[mix(lerp(2.0 * mapColor * color,1.0 - 2.0*(1.0-color)*(1.0-mapColor),min(1.0,max(0.0,10.0*(dot(vec4(0.25,0.65,0.1,0.0),color)- 0.45)))),mapColor,color.a);]],

            ["InverseDifference"] = [[mix(1.0-abs(mapColor-color),mapColor,color.a);]],

            ["Lighten"] = [[mix(max(color,mapColor),mapColor,color.a);]],

            ["Luminance"] = [[mix(dot(color,vec4(0.25,0.65,0.1,0.0))*normalize(mapColor),mapColor,color.a);]],

            ["Multiply"] = [[mix(color*mapColor,mapColor,color.a);]],

            ["Overlay"] = [[mix(lerp(2.0 * mapColor * color,1.0 - 2.0*(1.0-color)*(1.0-mapColor),min(1.0,max(0.0,10.0*(dot(vec4(0.25,0.65,0.1,0.0),mapColor)- 0.45)))),mapColor,color.a);]],

            ["Premultiplied"] = [[vec4(color.rgb + (1.0-color.a)*mapColor.rgb, (color.a+mapColor.a));]],

            ["Screen"] = [[mix(1.0-(1.0-mapColor)*(1.0-color),mapColor,color.a);]],

            ["SoftLight"] = [[mix(2.0*mapColor*color+mapColor*mapColor-2.0*mapColor*mapColor*color,mapColor,color.a);]],
            ["Subtract"] = [[mix(mapColor-color,mapColor,color.a);]],
        }

        local shaderFragStr = VFS.LoadFile("shaders/map_drawing.glsl")
        local shaderTemplate = {
            fragment = string.format(shaderFragStr, penBlenders[mode]),
            uniformInt = {
                mapTex = 0,
                patternTexture = 1,
                brushTexture = 2,
            },
        }

        local shader = Shaders.Compile(shaderTemplate, "pen")
        local shaderObj = {
            shader = shader,
            uniforms = {
                x1ID = gl.GetUniformLocation(shader, "x1"),
                x2ID = gl.GetUniformLocation(shader, "x2"),
                z1ID = gl.GetUniformLocation(shader, "z1"),
                z2ID = gl.GetUniformLocation(shader, "z2"),
                blendFactorID = gl.GetUniformLocation(shader, "blendFactor"),
                falloffFactorID = gl.GetUniformLocation(shader, "falloffFactor"),
                featureFactorID = gl.GetUniformLocation(shader, "featureFactor"),
                diffuseColorID = gl.GetUniformLocation(shader, "diffuseColor"),
                voidFactorID = gl.GetUniformLocation(shader, "voidFactor"),
            },
        }
        shaders.diffuse[mode] = shaderObj
    end

    return shaders.diffuse[mode]
end

function getVoidShader()
    _InitShaders()
    if shaders.void == nil then
        local shaderFragStr = VFS.LoadFile("shaders/void_drawing.glsl")
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
                patternTexture = 1,
            },
        }

        local shader = Shaders.Compile(shaderTemplate, "void")
        local shaderObj = {
            shader = shader,
            uniforms = {
                x1ID = gl.GetUniformLocation(shader, "x1"),
                x2ID = gl.GetUniformLocation(shader, "x2"),
                z1ID = gl.GetUniformLocation(shader, "z1"),
                z2ID = gl.GetUniformLocation(shader, "z2"),
                voidFactorID = gl.GetUniformLocation(shader, "voidFactor"),
            },
        }
        shaders.void = shaderObj
    end

    return shaders.void
end

function getBlurShader()
    _InitShaders()
    if shaders.blur == nil then
        local shaderFragStr = VFS.LoadFile("shaders/map_blur_drawing.glsl")
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
                patternTexture = 1,
            },
        }

        local shader = Shaders.Compile(shaderTemplate, "blur")
        local shaderObj = {
            shader = shader,
            uniforms = {
                blendFactorID = gl.GetUniformLocation(shader, "blendFactor"),
                kernelID = gl.GetUniformLocation(shader, "kernel"),
            },
        }
        shaders.blur = shaderObj
    end

    return shaders.blur
end

function getDNTSShader()
    _InitShaders()
    if shaders.dnts == nil then
        local shaderFragStr = VFS.LoadFile("shaders/dnts_drawing.glsl")
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
                patternTexture = 1,
            },
        }

        local shader = Shaders.Compile(shaderTemplate, "dnts")
        local shaderObj = {
            shader = shader,
            uniforms = {
                x1ID = gl.GetUniformLocation(shader, "x1"),
                x2ID = gl.GetUniformLocation(shader, "x2"),
                z1ID = gl.GetUniformLocation(shader, "z1"),
                z2ID = gl.GetUniformLocation(shader, "z2"),
                blendFactorID = gl.GetUniformLocation(shader, "blendFactor"),
                colorIndexID = gl.GetUniformLocation(shader, "colorIndex"),
                exclusiveID = gl.GetUniformLocation(shader, "exclusive"),
                valueID = gl.GetUniformLocation(shader, "value"),
            },
        }
        shaders.dnts = shaderObj
    end

    return shaders.dnts
end

local function DrawQuads(mCoord, tCoord, vCoord)
    gl.MultiTexCoord(0, mCoord[1], mCoord[2])
    gl.MultiTexCoord(1, 0, 0 )
    gl.MultiTexCoord(2, tCoord[1], tCoord[2] )
    gl.Vertex(vCoord[1], vCoord[2])

    gl.MultiTexCoord(0, mCoord[3], mCoord[4])
    gl.MultiTexCoord(1, 0, 1 )
    gl.MultiTexCoord(2, tCoord[3], tCoord[4] )
    gl.Vertex(vCoord[3], vCoord[4])

    gl.MultiTexCoord(0, mCoord[5], mCoord[6])
    gl.MultiTexCoord(1, 1, 1 )
    gl.MultiTexCoord(2, tCoord[5], tCoord[6] )
    gl.Vertex(vCoord[5], vCoord[6])

    gl.MultiTexCoord(0, mCoord[7], mCoord[8])
    gl.MultiTexCoord(1, 1, 0 )
    gl.MultiTexCoord(2, tCoord[7], tCoord[8] )
    gl.Vertex(vCoord[7], vCoord[8])
end

local function ApplyTexture(oldTexture, mCoord, tCoord, vCoord)
    gl.Texture(0, oldTexture)

    -- TODO: move all this to a vertex shader?
    gl.BeginEnd(GL.QUADS, DrawQuads, mCoord, tCoord, vCoord)
end

local function OffsetCoords(tCoord, offsetX, offsetY)
    for i = 1, #tCoord, 2 do
        tCoord[i] = tCoord[i] + offsetX
        tCoord[i+1] = tCoord[i+1] + offsetY
    end
end

local function ScaleCoords(tCoord, scaleX, scaleY)
    for i = 1, #tCoord, 2 do
        tCoord[i] = tCoord[i] * scaleX
        tCoord[i+1] = tCoord[i+1] * scaleY
    end
end

local function rotate(x, y, angle)
    return x * math.cos(angle) - y * math.sin(angle),
        x * math.sin(angle) + y * math.cos(angle)
end

local function RotateCoords(tCoord, angle)
    -- rotate center
    local tdx = tCoord[5] - tCoord[1]
    local tdz = tCoord[4] - tCoord[2]
    for i = 1, #tCoord, 2 do
        tCoord[i]   			 = tCoord[i] - tdx
        tCoord[i + 1] 			 = tCoord[i + 1] - tdz
        tCoord[i], tCoord[i + 1] = rotate(tCoord[i], tCoord[i + 1], angle)
        tCoord[i]				 = tCoord[i] + tdx
        tCoord[i + 1] 			 = tCoord[i + 1] + tdz
    end
end

local function _GetCoords(x, z, sizeX, sizeZ, mx, mz, mSizeX, mSizeZ)
    local mCoord = {
        mx,              mz,
        mx,              mz + mSizeZ,
        mx + mSizeX,     mz + mSizeZ,
        mx + mSizeX,     mz
    }
    local vCoord = {} -- vertex coords
-- 	for i = 1, #mCoord, 2 do
-- 		vCoord[i]     = mCoord[i]     * 2 - 1
-- 		vCoord[i + 1] = mCoord[i + 1] * 2 - 1
-- 	end
    for i = 1, #mCoord do
        vCoord[i]     = mCoord[i]     * 2 - 1
    end

    -- texture coords
    local tCoord = {
        x,             z,
        x,             z + sizeZ,
        x + sizeX,     z + sizeZ,
        x + sizeX,     z
    }

    return mCoord, tCoord, vCoord
end

local function GenerateCoords(x, z, sizeX, sizeZ, mx, mz, mSizeX, mSizeZ, opts)
    local mCoord, tCoord, vCoord = _GetCoords(x, z, sizeX, sizeZ, mx, mz, mSizeX, mSizeZ)

    if opts.texOffsetX then
        OffsetCoords(tCoord, opts.texOffsetX * sizeX, opts.texOffsetY * sizeZ)
    end
    if opts.texScale then
        ScaleCoords(tCoord, opts.texScale, opts.texScale)
    end
    if opts.rotation then
        RotateCoords(tCoord, math.rad(opts.rotation))
    end

    return mCoord, tCoord, vCoord
end

function DrawDiffuse(opts, x, z, size)
    if not opts["diffuseEnabled"] or not opts.brushTexture.diffuse then
        return
    end

    local textures = SB.model.textureManager:getMapTextures(x, z, x + size, z + size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = SB.model.textureManager:GetTMPs(#textures)
    for i, v in pairs(textures) do
        local mapTextureObj = v[1]
        local mapTexture = mapTextureObj.texture

        local tmp = tmps[i]
        SB.model.textureManager:Blit(mapTexture, tmp)
    end

    local shaderObj = getPenShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))
    gl.Texture(2, SB.model.textureManager:GetTexture(opts.brushTexture.diffuse))

    gl.Uniform(uniforms.blendFactorID, opts.blendFactor)
    gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
    gl.Uniform(uniforms.featureFactorID, opts.featureFactor)
    opts.diffuseColor[4] = 1.0
    gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))
    --gl.Uniform(uniforms.voidFactorID, opts.voidFactor)

    local texSize = SB.model.textureManager.TEXTURE_SIZE
    x = x / texSize
    z = z / texSize
    size = size / texSize
    for i, v in pairs(textures) do
        local mapTextureObj, _, coords = v[1], v[2], v[3]
        local mx, mz = coords[1] / texSize, coords[2] / texSize

        local mapTexture = mapTextureObj.texture
        mapTextureObj.dirty = true

        local mCoord, tCoord, vCoord = GenerateCoords(x, z, size, size, mx, mz, size, size, opts)

        gl.Uniform(uniforms.x1ID, mCoord[1])
        gl.Uniform(uniforms.x2ID, mCoord[5])
        gl.Uniform(uniforms.z1ID, mCoord[2])
        gl.Uniform(uniforms.z2ID, mCoord[4])

        gl.RenderToTexture(mapTexture, ApplyTexture, tmps[i], mCoord, tCoord, vCoord)
    end
    CheckGLSL()

    -- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.Texture(2, false)
    gl.UseShader(0)
end

function DrawBlur(opts, x, z, size)
    local textures = SB.model.textureManager:getMapTextures(x, z, x + size, z + size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = SB.model.textureManager:GetTMPs(#textures)
    for i, v in pairs(textures) do
        local mapTextureObj = v[1]
        local mapTexture = mapTextureObj.texture

        local tmp = tmps[i]
        SB.model.textureManager:Blit(mapTexture, tmp)
    end

    local shaderObj = getBlurShader()
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

    gl.Uniform(uniforms.blendFactorID, opts.blendFactor)
    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))

    local texSize = SB.model.textureManager.TEXTURE_SIZE
    x = x / texSize
    z = z / texSize
    size = size / texSize
    for i, v in pairs(textures) do
        local mapTextureObj, _, coords = v[1], v[2], v[3]
        local mx, mz = coords[1] / texSize, coords[2] / texSize

        local mapTexture = mapTextureObj.texture
        mapTextureObj.dirty = true

        local mCoord, tCoord, vCoord = GenerateCoords(x, z, size, size, mx, mz, size, size, opts)

        gl.RenderToTexture(mapTexture, ApplyTexture, tmps[i], mCoord, tCoord, vCoord)
    end
    CheckGLSL()

    -- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)
end

function DrawVoid(opts, x, z, size)
    local textures = SB.model.textureManager:getMapTextures(x, z, x + size, z + size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = SB.model.textureManager:GetTMPs(#textures)
    for i, v in pairs(textures) do
        local mapTextureObj = v[1]
        local mapTexture = mapTextureObj.texture

        local tmp = tmps[i]
        SB.model.textureManager:Blit(mapTexture, tmp)
    end

    local shaderObj = getVoidShader()
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    gl.Uniform(uniforms.voidFactorID, opts.voidFactor)

    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))

    local texSize = SB.model.textureManager.TEXTURE_SIZE
    x = x / texSize
    z = z / texSize
    size = size / texSize
    for i, v in pairs(textures) do
        local mapTextureObj, _, coords = v[1], v[2], v[3]
        local mx, mz = coords[1] / texSize, coords[2] / texSize

        local mapTexture = mapTextureObj.texture
        mapTextureObj.dirty = true

        local mCoord, tCoord, vCoord = GenerateCoords(x, z, size, size, mx, mz, size, size, opts)

        gl.Uniform(uniforms.x1ID, mCoord[1])
        gl.Uniform(uniforms.x2ID, mCoord[5])
        gl.Uniform(uniforms.z1ID, mCoord[2])
        gl.Uniform(uniforms.z2ID, mCoord[4])

        gl.RenderToTexture(mapTexture, ApplyTexture, tmps[i], mCoord, tCoord, vCoord)
    end
    CheckGLSL()

    -- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)
end

function DrawDNTS(opts, x, z, size)
    local shadingTmps = {}
    local texSize = SB.model.textureManager.TEXTURE_SIZE
    local texType = "splat_distr"
    local shadingTex = SB.model.textureManager.shadingTextures[texType]

    SB.model.textureManager:backupMapShadingTexture(texType)
    local tmpTexName = texType.."tmp"
    shadingTmps[texType] = SB.model.textureManager[tmpTexName]
    if SB.model.textureManager[tmpTexName] == nil then
        local texInfo = gl.TextureInfo(shadingTex)
        local texSizeX, texSizeZ = texInfo.xsize, texInfo.ysize
        SB.model.textureManager[tmpTexName] = gl.CreateTexture(texSizeX, texSizeZ, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true,
        })
        shadingTmps[texType] = SB.model.textureManager[tmpTexName]
    end
    SB.model.textureManager:Blit(shadingTex, shadingTmps[texType])

    local shaderObj = getDNTSShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    gl.Uniform(uniforms.blendFactorID, opts.blendFactor)
    gl.UniformInt(uniforms.colorIndexID, opts.colorIndex)
    gl.UniformInt(uniforms.exclusiveID, opts.exclusive)
    gl.Uniform(uniforms.valueID, opts.value)

    x = x / texSize
    z = z / texSize
    size = size / texSize

    gl.Blending("enable")
    local texInfo = gl.TextureInfo(shadingTex)
    local sizeX  = size * texSize / Game.mapSizeX
    local sizeZ  = size * texSize / Game.mapSizeZ
    local mx     = x    * texSize / Game.mapSizeX
    local mz     = z    * texSize / Game.mapSizeZ

    local mCoord, tCoord, vCoord = GenerateCoords(x, z, size, size, mx, mz, sizeX, sizeZ, opts)

    gl.Uniform(uniforms.x1ID, mCoord[1])
    gl.Uniform(uniforms.x2ID, mCoord[5])
    gl.Uniform(uniforms.z1ID, mCoord[2])
    gl.Uniform(uniforms.z2ID, mCoord[4])

    gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))
    gl.RenderToTexture(shadingTex, ApplyTexture, shadingTmps[texType], mCoord, tCoord, vCoord)

    CheckGLSL()

    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)
end

function DrawShadingTextures(opts, x, z, size)
    local shadingTmps = {}
    local texSize = SB.model.textureManager.TEXTURE_SIZE
    for texType, shadingTex in pairs(SB.model.textureManager.shadingTextures) do
        if opts.brushTexture[texType] and opts[texType .. "Enabled"] then
            SB.model.textureManager:backupMapShadingTexture(texType)
            local tmpTexName = texType.."tmp"
            shadingTmps[texType] = SB.model.textureManager[tmpTexName]
            if SB.model.textureManager[tmpTexName] == nil then
                local texInfo = gl.TextureInfo(shadingTex)
                local texSizeX, texSizeZ = texInfo.xsize, texInfo.ysize
                SB.model.textureManager[tmpTexName] = gl.CreateTexture(texSizeX, texSizeZ, {
                    border = false,
                    min_filter = GL.LINEAR,
                    mag_filter = GL.LINEAR,
                    wrap_s = GL.CLAMP_TO_EDGE,
                    wrap_t = GL.CLAMP_TO_EDGE,
                    fbo = true,
                })
                shadingTmps[texType] = SB.model.textureManager[tmpTexName]
            end
            SB.model.textureManager:Blit(shadingTex, shadingTmps[texType])
        end
    end

    local shaderObj = getPenShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    gl.Blending("disable")
    gl.UseShader(shader)

    gl.Uniform(uniforms.blendFactorID, opts.blendFactor)
    gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
    gl.Uniform(uniforms.featureFactorID, opts.featureFactor)
    opts.diffuseColor[4] = 1.0
    gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))
    --gl.Uniform(uniforms.voidFactorID, opts.voidFactor)

    x = x / texSize
    z = z / texSize
    size = size / texSize
    for texType, shadingTex in pairs(SB.model.textureManager.shadingTextures) do
        if opts.brushTexture[texType] and opts[texType .. "Enabled"] then
            gl.Blending("disable")
            local texInfo = gl.TextureInfo(shadingTex)
            local sizeX  = size * texSize / Game.mapSizeX
            local sizeZ  = size * texSize / Game.mapSizeZ
            local mx     = x    * texSize / Game.mapSizeX
            local mz     = z    * texSize / Game.mapSizeZ

            local mCoord, tCoord, vCoord = GenerateCoords(x, z, size, size, mx, mz, sizeX, sizeZ, opts)

            gl.Uniform(uniforms.x1ID, mCoord[1])
            gl.Uniform(uniforms.x2ID, mCoord[5])
            gl.Uniform(uniforms.z1ID, mCoord[2])
            gl.Uniform(uniforms.z2ID, mCoord[4])

            gl.Texture(1, SB.model.textureManager:GetTexture(opts.patternTexture))
            gl.Texture(2, SB.model.textureManager:GetTexture(opts.brushTexture[texType]))
            gl.RenderToTexture(shadingTex, ApplyTexture, shadingTmps[texType], mCoord, tCoord, vCoord)

            CheckGLSL()
        end
    end

    -- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.Texture(2, false)
    gl.UseShader(0)
end

-- FIXME: This is unnecessary probably. Confirm with engine code
function CheckGLSL()
    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Log.Error("Shader error!")
        Log.Error(errors)
    end
end

function WidgetTerrainChangeTextureCommand:SetTexture(opts)
    local x, z = opts.x, opts.z
    local size = opts.size

    -- change size depending on falloff (larger size if falloff factor is small)
    x = x
    z = z
    size = size

    if opts.paintMode == "void" then
        DrawVoid(opts, x, z, size)
    elseif opts.paintMode == "blur" then
        DrawBlur(opts, x, z, size)
    elseif opts.paintMode == "paint" then
        DrawDiffuse(opts, x, z, size)
        DrawShadingTextures(opts, x, z, size)
    elseif opts.paintMode == "dnts" then
        DrawDNTS(opts, x, z, size)
    else
        Log.Error("Unexpected paint mode: " .. tostring(opts.paintMode))
    end
end

WidgetUndoTerrainChangeTextureCommand = Command:extends{}
WidgetUndoTerrainChangeTextureCommand.className = "WidgetUndoTerrainChangeTextureCommand"

function WidgetUndoTerrainChangeTextureCommand:execute()
    SB.delayGL(function()
        SB.model.textureManager:PopStack()
    end)
end

WidgetTerrainChangeTexturePushStackCommand = Command:extends{}
WidgetTerrainChangeTexturePushStackCommand.className = "WidgetTerrainChangeTexturePushStackCommand"

function WidgetTerrainChangeTexturePushStackCommand:execute()
    SB.delayGL(function()
        SB.model.textureManager:PushStack()
    end)
end
