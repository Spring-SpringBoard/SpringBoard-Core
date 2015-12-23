WidgetTerrainChangeTextureCommand = AbstractCommand:extends{}
WidgetTerrainChangeTextureCommand.className = "WidgetTerrainChangeTextureCommand"

function WidgetTerrainChangeTextureCommand:init(opts)
    self.className = "WidgetTerrainChangeTextureCommand"
    self.opts = opts
end

function WidgetTerrainChangeTextureCommand:execute()
    SCEN_EDIT.delayGL(function()
        self:SetTexture(self.opts)
    end)
end


local function _InitShaders()
	if shaders == nil then
		shaders = {
			diffuse = {},
			normal = {},
			smart = {},
			void = nil,
		}
	end
end

function getNormalShader(mode)
    _InitShaders()
    if shaders.normal[mode] == nil then
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

        local shaderFragStr = VFS.LoadFile("shaders/normal_drawing.glsl")
        local shaderTemplate = {
            fragment = string.format(shaderFragStr, penBlenders[mode]),
            uniformInt = {
                mapTex = 0,
                paintTex = 1,
            },
        }

        local shader = gl.CreateShader(shaderTemplate)
        local errors = gl.GetShaderLog(shader)
        if errors ~= "" then
            Spring.Echo(errors)
        else
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
                },
            }
            shaders.normal[mode] = shaderObj
        end
    end

    return shaders.normal[mode]
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
                paintTex = 1,
            },
        }

        local shader = gl.CreateShader(shaderTemplate)
        local errors = gl.GetShaderLog(shader)
        if errors ~= "" then
            Spring.Echo(errors)
        else
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
    end

    return shaders.diffuse[mode]
end

function getSmartShader(mode)
    _InitShaders()
    if shaders.smart[mode] == nil then
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

        local shaderFragStr = VFS.LoadFile("shaders/smart_drawing.glsl")
        local shaderTemplate = {
            fragment = string.format(shaderFragStr, penBlenders[mode]),
            uniformInt = {
                mapTex = 0,
				heightmapTex = 1,
                paintTex1 = 2,
				paintTex2 = 3,
				paintTex3 = 4,
				paintTex4 = 5,
            },
        }

        local shader = gl.CreateShader(shaderTemplate)
        local errors = gl.GetShaderLog(shader)
        if errors ~= "" then
            Spring.Echo(errors)
        else
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
					
					minHeightID = gl.GetUniformLocation(shader, "minHeight"),
					minSlopeID = gl.GetUniformLocation(shader, "minSlope"),
                },
            }
            shaders.smart[mode] = shaderObj
        end
    end

    return shaders.smart[mode]
end

function getVoidShader()
	_InitShaders()
    if shaders.void == nil then
        local shaderFragStr = VFS.LoadFile("shaders/void_drawing.glsl")
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
            },
        }

        local shader = gl.CreateShader(shaderTemplate)
        local errors = gl.GetShaderLog(shader)
        if errors ~= "" then
            Spring.Echo(errors)
        else
            local shaderObj = {
                shader = shader,
                uniforms = {
                    x1ID = gl.GetUniformLocation(shader, "x1"),
                    x2ID = gl.GetUniformLocation(shader, "x2"),
                    z1ID = gl.GetUniformLocation(shader, "z1"),
                    z2ID = gl.GetUniformLocation(shader, "z2"),
                    falloffFactorID = gl.GetUniformLocation(shader, "falloffFactor"),
					voidFactorID = gl.GetUniformLocation(shader, "voidFactor"),
                },
            }
            shaders.void = shaderObj
        end
    end

    return shaders.void
end

local function DrawQuads(mCoord, tCoord, vCoord)
    gl.MultiTexCoord(0, mCoord[1], mCoord[2])
    gl.MultiTexCoord(1, tCoord[1], tCoord[2] )
    gl.Vertex(vCoord[1], vCoord[2])

    gl.MultiTexCoord(0, mCoord[3], mCoord[4])
    gl.MultiTexCoord(1, tCoord[3], tCoord[4] )
    gl.Vertex(vCoord[3], vCoord[4])

    gl.MultiTexCoord(0, mCoord[5], mCoord[6])
    gl.MultiTexCoord(1, tCoord[5], tCoord[6] )
    gl.Vertex(vCoord[5], vCoord[6])

    gl.MultiTexCoord(0, mCoord[7], mCoord[8])
    gl.MultiTexCoord(1, tCoord[7], tCoord[8] )
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
		mx,              mz + 2 * mSizeZ,
		mx + 2 * mSizeX, mz + 2 * mSizeZ,
		mx + 2 * mSizeX, mz
	}
	local vCoord = {} -- vertex coords
	for i = 1, #mCoord, 2 do
		vCoord[i]     = mCoord[i]     * 2 - 1
		vCoord[i + 1] = mCoord[i + 1] * 2 - 1
	end

	-- texture coords
	local tCoord = {
		x,             z,
		x,             z + 2 * sizeZ,
		x + 2 * sizeX, z + 2 * sizeZ,
		x + 2 * sizeX, z
	}
	
	return mCoord, tCoord, vCoord
end

local function GenerateCoords(x, z, sizeX, sizeZ, mx, mz, mSizeX, mSizeZ, opts)
	local mCoord, tCoord, vCoord = _GetCoords(x, z, sizeX, sizeZ, mx, mz, mSizeX, mSizeZ)

	OffsetCoords(tCoord, opts.texOffsetX, opts.texOffsetY)
	ScaleCoords(tCoord, opts.texScale, opts.texScale)
	RotateCoords(tCoord, opts.rotation * math.pi / 180)
	
	return mCoord, tCoord, vCoord
end

function DrawDiffuse(opts, x, z, size)
	if not opts["diffuseEnabled"] or not opts.paintTexture.diffuse then
		return
	end
	
	local textures = SCEN_EDIT.model.textureManager:getMapTextures(x, z, x + 2 * size, z + 2 * size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = SCEN_EDIT.model.textureManager:GetTMPs(#textures)
    for i, v in pairs(textures) do
        local mapTextureObj = v[1]
        local mapTexture = mapTextureObj.texture

        local tmp = tmps[i]
        SCEN_EDIT.model.textureManager:Blit(mapTexture, tmp)
    end
	
	local shaderObj = getPenShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms
	
	gl.Blending("disable")
    gl.UseShader(shader)

    gl.Texture(1, SCEN_EDIT.model.textureManager:GetTexture(opts.paintTexture.diffuse))

    gl.Uniform(uniforms.blendFactorID, opts.blendFactor)
    gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
    gl.Uniform(uniforms.featureFactorID, opts.featureFactor)
    gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))
	gl.Uniform(uniforms.voidFactorID, opts.voidFactor)

    local texSize = SCEN_EDIT.model.textureManager.TEXTURE_SIZE
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

function DrawVoid(opts, x, z, size)
	local textures = SCEN_EDIT.model.textureManager:getMapTextures(x, z, x + 2 * size, z + 2 * size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = SCEN_EDIT.model.textureManager:GetTMPs(#textures)
    for i, v in pairs(textures) do
        local mapTextureObj = v[1]
        local mapTexture = mapTextureObj.texture

        local tmp = tmps[i]
        SCEN_EDIT.model.textureManager:Blit(mapTexture, tmp)
    end
	
	local shaderObj = getVoidShader()
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms
	
	gl.Blending("disable")
    gl.UseShader(shader)

    gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
	gl.Uniform(uniforms.voidFactorID, opts.voidFactor)

    local texSize = SCEN_EDIT.model.textureManager.TEXTURE_SIZE
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

function DrawShadingTextures(opts, x, z, size)
	local shadingTmps = {}
	local texSize = SCEN_EDIT.model.textureManager.TEXTURE_SIZE
	for texType, shadingTex in pairs(SCEN_EDIT.model.textureManager.shadingTextures) do
		if opts.paintTexture[texType] and opts[texType .. "Enabled"] then
			SCEN_EDIT.model.textureManager:backupMapShadingTexture(texType)
			local tmpTexName = texType.."tmp"
			shadingTmps[texType] = SCEN_EDIT.model.textureManager[tmpTexName]
			if SCEN_EDIT.model.textureManager[tmpTexName] == nil then
				local texInfo = gl.TextureInfo(shadingTex)
				local texSizeX, texSizeZ = texInfo.xsize, texInfo.ysize
				SCEN_EDIT.model.textureManager[tmpTexName] = gl.CreateTexture(texSizeX, texSizeZ, {
					border = false,
					min_filter = GL.LINEAR,
					mag_filter = GL.LINEAR,
					wrap_s = GL.CLAMP_TO_EDGE,
					wrap_t = GL.CLAMP_TO_EDGE,
					fbo = true,
				})
				shadingTmps[texType] = SCEN_EDIT.model.textureManager[tmpTexName]
			end
			SCEN_EDIT.model.textureManager:Blit(shadingTex, shadingTmps[texType])
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
    gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))
	gl.Uniform(uniforms.voidFactorID, opts.voidFactor)
	
	x = x / texSize
	z = z / texSize
	size = size / texSize
	for texType, shadingTex in pairs(SCEN_EDIT.model.textureManager.shadingTextures) do
		if texType ~= "normal" and opts.paintTexture[texType] and opts[texType .. "Enabled"] then
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
			
			gl.Texture(1, SCEN_EDIT.model.textureManager:GetTexture(opts.paintTexture[texType]))
			gl.RenderToTexture(shadingTex, ApplyTexture, shadingTmps[texType], mCoord, tCoord, vCoord)
			
			CheckGLSL()
		end
	end

	if opts.paintTexture.normal and opts.normalEnabled then
		gl.Blending("disable")
		local shaderObj = getPenShader(opts.mode)--getNormalShader(opts.mode)
		local shader = shaderObj.shader
		local uniforms = shaderObj.uniforms
		
		gl.UseShader(shader)

		gl.Texture(1, SCEN_EDIT.model.textureManager:GetTexture(opts.paintTexture.normal))

		gl.Uniform(uniforms.blendFactorID, opts.blendFactor)
		gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
		gl.Uniform(uniforms.featureFactorID, opts.featureFactor)
		gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))
		
		local texInfo = gl.TextureInfo(opts.paintTexture.normal)
		local sizeX  = size * texSize / Game.mapSizeX
		local sizeZ  = size * texSize / Game.mapSizeZ
		local mx     = x    * texSize / Game.mapSizeX
		local mz     = z    * texSize / Game.mapSizeZ

		local mCoord, tCoord, vCoord = GenerateCoords(x, z, size, size, mx, mz, sizeX, sizeZ, opts)
			
		gl.Uniform(uniforms.x1ID, mCoord[1])
		gl.Uniform(uniforms.x2ID, mCoord[5])
		gl.Uniform(uniforms.z1ID, mCoord[2])
		gl.Uniform(uniforms.z2ID, mCoord[4])
		
		
		gl.RenderToTexture(SCEN_EDIT.model.textureManager.shadingTextures.normal, ApplyTexture, shadingTmps.normal, mCoord, tCoord, vCoord)

		CheckGLSL()
	end
	
	-- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
	gl.UseShader(0)
end

function DrawSmart(opts, x, z, size)
	if not opts["diffuseEnabled"] or not opts.paintTexture.diffuse then
		return
	end
	
	local textures = SCEN_EDIT.model.textureManager:getMapTextures(x, z, x + 2 * size, z + 2 * size)
    -- create temporary textures to be used as source for modifying the textures later on
    local tmps = SCEN_EDIT.model.textureManager:GetTMPs(#textures)
    for i, v in pairs(textures) do
        local mapTextureObj = v[1]
        local mapTexture = mapTextureObj.texture

        local tmp = tmps[i]
        SCEN_EDIT.model.textureManager:Blit(mapTexture, tmp)
    end
	
	local shaderObj = getSmartShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms
	
	gl.Blending("disable")
    gl.UseShader(shader)
	
	gl.Texture(1, "$heightmap")
    gl.Uniform(uniforms.blendFactorID, opts.blendFactor)
    gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
    gl.Uniform(uniforms.featureFactorID, opts.featureFactor)
    gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))
	gl.Uniform(uniforms.voidFactorID, opts.voidFactor)
	
	local order = {}
	for i, texture in pairs(opts.textures) do
		table.insert(order, { texture.minSlope, i})
	end
	table.sort(order, function(t1, t2) return t1[1] < t2[1] end)
	local minSlopes = {}
	for i, item in pairs(order) do
		table.insert(minSlopes, item[1])
		local texture = opts.textures[item[2]]
		gl.Texture(1 + i, SCEN_EDIT.model.textureManager:GetTexture(texture.texture.diffuse))
	end
	Spring.Echo(minSlopes)
	gl.Uniform(uniforms.minSlopeID, unpack(minSlopes))
	
	local texSize = SCEN_EDIT.model.textureManager.TEXTURE_SIZE
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
	for i, item in pairs(order) do
		gl.Texture(1 + i, false)
	end
	gl.UseShader(0)
end

function CheckGLSL()
	local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Spring.Log("Scened", LOG.ERROR, "Shader error!")
        Spring.Log("Scened", LOG.ERROR, errors)
    end
end

function WidgetTerrainChangeTextureCommand:SetTexture(opts)
    local x, z = opts.x, opts.z
    local size = opts.size

    -- change size depending on falloff (larger size if falloff factor is small)
    local fs = 2
    x = x - size * (fs - opts.falloffFactor * fs)
    z = z - size * (fs - opts.falloffFactor * fs)
    size = size * (fs + 1 - opts.falloffFactor * fs)

	if opts.void then
		DrawVoid(opts, x, z, size)
	elseif opts.smartPaint then
		Spring.Echo("Smart paint!", #opts.textures)
		DrawSmart(opts, x, z, size)
	else
		DrawDiffuse(opts, x, z, size)
		DrawShadingTextures(opts, x, z, size)
	end
end

WidgetUndoTerrainChangeTextureCommand = AbstractCommand:extends{}
WidgetUndoTerrainChangeTextureCommand.className = "WidgetUndoTerrainChangeTextureCommand"

function WidgetUndoTerrainChangeTextureCommand:execute()
    SCEN_EDIT.delayGL(function()
		SCEN_EDIT.model.textureManager:PopStack()
    end)
end

WidgetTerrainChangeTexturePushStackCommand = AbstractCommand:extends{}
WidgetTerrainChangeTexturePushStackCommand.className = "WidgetTerrainChangeTexturePushStackCommand"

function WidgetTerrainChangeTexturePushStackCommand:execute()
    SCEN_EDIT.delayGL(function()
        SCEN_EDIT.model.textureManager:PushStack()
    end)
end
