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

function getPenShader(mode)
    if shaders == nil then
        shaders = {}
    end
    if shaders[mode] == nil then
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
            --//Pako's TODO make custom shaders for specular textures
        }

        local shaderFragStr = [[                    

        uniform sampler2D mapTex;
        uniform sampler2D penTex;
        uniform sampler2D paintTex;
        
        uniform float x1, x2, z1, z2;
        uniform float blendFactor;
        uniform float falloffFactor;
        uniform float featureFactor;
        uniform vec4 diffuseColor;

        vec4 mix(vec4 penColor, vec4 mapColor, float alpha) {
            return vec4(penColor.rgb * alpha + mapColor.rgb * (1.0 - alpha), 1.0);
        }

        void main(void)
        {
            vec4 mapColor = texture2D(mapTex, gl_TexCoord[0].st);
            vec4 penColor = texture2D(penTex, gl_TexCoord[1].st);
            vec4 texColor = texture2D(paintTex, gl_TexCoord[2].st);

            vec4 color = (diffuseColor * texColor * penColor);

            // mode goes here
            color = %s;

            //alpha *= 20;
            //alpha = floor(alpha) / 20;
            //color.rgb = color.rgb * alpha;

            // extract texture features
            featureFactor = (1 - featureFactor) / 2;
            color = mix(min(color, (max(color,mapColor+featureFactor)-featureFactor)-featureFactor)+featureFactor,mapColor,color.a);

            // apply only a percentage part of the texture
            //blendFactor = blendFactor * blendFactor;
            color = mix(color, mapColor, blendFactor);

            // calculate alpha (smaller the further away it is), used to draw circles
            vec2 size = vec2(x2 - x1, z2 - z1);
            vec2 center = size / 2;
            vec2 delta = (gl_TexCoord[0].xy - vec2(x1, z1) - center) / size;
            float distance = sqrt(delta.x * delta.x + delta.y * delta.y);
            float alpha = 1 - 2 * distance;
            alpha = clamp(alpha, 0, 1);
            color = mix(color, mapColor, alpha);
            
            // falloff crispness (use previously calculated alpha to make for a smooth falloff blending
            float falloffAlpha = 1 - min(1.0f, alpha + falloffFactor);
            color = mix(min(color, (max(color,mapColor+falloffAlpha)-falloffAlpha)-falloffAlpha)+falloffAlpha,mapColor,color.a);

            gl_FragColor = color;
            gl_FragColor.a = 1; // there are issues if this is less than 1
        }
        ]]
        local shaderTemplate = {
            fragment = string.format(shaderFragStr,penBlenders[mode]),
            uniformInt = {
                mapTex = 0,
                penTex = 1,
                paintTex = 2,
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
            shaders[mode] = shaderObj
        end
    end

    return shaders[mode]
end

local function DrawQuads(mCoord, tCoord, vCoord, detailTexScale)
    gl.MultiTexCoord(0, mCoord[1], mCoord[2])
    gl.MultiTexCoord(1, tCoord[1] * detailTexScale, tCoord[2] * detailTexScale)
    gl.MultiTexCoord(2, tCoord[1], tCoord[2] )
    gl.Vertex(vCoord[1], vCoord[2])

    gl.MultiTexCoord(0, mCoord[3], mCoord[4])
    gl.MultiTexCoord(1, tCoord[3] * detailTexScale, tCoord[4] * detailTexScale)
    gl.MultiTexCoord(2, tCoord[3], tCoord[4] )
    gl.Vertex(vCoord[3], vCoord[4])

    gl.MultiTexCoord(0, mCoord[5], mCoord[6])
    gl.MultiTexCoord(1, tCoord[5] * detailTexScale, tCoord[6] * detailTexScale)
    gl.MultiTexCoord(2, tCoord[5], tCoord[6] )
    gl.Vertex(vCoord[5], vCoord[6])

    gl.MultiTexCoord(0, mCoord[7], mCoord[8])
    gl.MultiTexCoord(1, tCoord[7] * detailTexScale, tCoord[8] * detailTexScale)
    gl.MultiTexCoord(2, tCoord[7], tCoord[8] )
    gl.Vertex(vCoord[7], vCoord[8])
end

local function ApplyTexture(oldTexture, mCoord, tCoord, vCoord, detailTexScale)
    gl.Texture(0, oldTexture)

    -- TODO: move all this to a vertex shader?
    gl.BeginEnd(GL.QUADS, DrawQuads, mCoord, tCoord, vCoord, detailTexScale)
end

function WidgetTerrainChangeTextureCommand:SetTexture(opts)
    local x, z = opts.x, opts.z
    local size = opts.size

    -- change size depending on falloff (larger size if falloff factor is small)
    local fs = 2
    x = x - size * (fs - opts.falloffFactor * fs)
    z = z - size * (fs - opts.falloffFactor * fs)
    size = size * (fs + 1 - opts.falloffFactor * fs)

    local shaderObj = getPenShader(opts.mode)
    local shader = shaderObj.shader
    local uniforms = shaderObj.uniforms

    local textures = SCEN_EDIT.model.textureManager:getMapTextures(x, z, x + 2 * size, z + 2 * size)

    -- copy to old texture
    local tmps = SCEN_EDIT.model.textureManager:GetTMPs(#textures)
    for i, v in pairs(textures) do
        local mapTextureObj, _, coords = v[1], v[2], v[3]
        local mapTexture = mapTextureObj.texture

        local tmp = tmps[i]
        SCEN_EDIT.model.textureManager:Blit(mapTexture, tmp)
    end

    gl.UseShader(shader)

    gl.Texture(1, SCEN_EDIT.model.textureManager:GetTexture(opts.penTexture))
    gl.Texture(2, SCEN_EDIT.model.textureManager:GetTexture(opts.paintTexture))

    gl.Uniform(uniforms.blendFactorID, opts.blendFactor)
    gl.Uniform(uniforms.falloffFactorID, opts.falloffFactor)
    gl.Uniform(uniforms.featureFactorID, opts.featureFactor)
    gl.Uniform(uniforms.diffuseColorID, unpack(opts.diffuseColor))

    local texSize = 1024
    for i, v in pairs(textures) do
        local mapTextureObj, _, coords = v[1], v[2], v[3]
        local dx, dz = coords[1], coords[2]

        local mapTexture = mapTextureObj.texture
        mapTextureObj.dirty = true

        local coords = {
            dx,            dz,
            dx,            dz + 2 * size,
            dx + 2 * size, dz + 2 * size,
            dx + 2 * size, dz
        }
        local vCoord = {} -- vertex coords
        local mCoord = {} -- map coordinates
        for i = 1, #coords do
            vCoord[i] = coords[i] / texSize * 2 - 1
            mCoord[i] = coords[i] / texSize
        end

        -- texture coords
        local tCoord = {
            x,            z,
            x,            z + 2 * size,
            x + 2 * size, z + 2 * size,
            x + 2 * size, z
        }
        for i = 1, #tCoord, 2 do
            tCoord[i] = (tCoord[i] / texSize + opts.texOffsetX) * opts.texScale
            tCoord[i+1] = (tCoord[i+1] / texSize + opts.texOffsetY) * opts.texScale
        end

        gl.Uniform(uniforms.x1ID, mCoord[1])
        gl.Uniform(uniforms.x2ID, mCoord[5])
        gl.Uniform(uniforms.z1ID, mCoord[2])
        gl.Uniform(uniforms.z2ID, mCoord[4])

        gl.RenderToTexture(mapTexture, ApplyTexture, tmps[i], mCoord, tCoord, vCoord, opts.detailTexScale)
    end
    -- texture 0 is changed multiple times inside the for loops, but it's OK to disabled it just once here
    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.Texture(2, false)

    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Spring.Log("scened", LOG.ERROR, "Shader error!")
        Spring.Log("scened", LOG.ERROR, errors)
    end
    gl.UseShader(0)
end

WidgetUndoTerrainChangeTextureCommand = AbstractCommand:extends{}
WidgetUndoTerrainChangeTextureCommand.className = "WidgetUndoTerrainChangeTextureCommand"

function WidgetUndoTerrainChangeTextureCommand:execute()
    SCEN_EDIT.delayGL(function()
        local stack = SCEN_EDIT.model.textureManager.stack
        SCEN_EDIT.model.textureManager.oldMapFBOTextures = stack[#stack]

        for i, v in pairs(SCEN_EDIT.model.textureManager.oldMapFBOTextures) do
            for j, oldTextureObj in pairs(v) do
                local mapTextureObj = SCEN_EDIT.model.textureManager.mapFBOTextures[i][j]
                local mapTexture = mapTextureObj.texture
                SCEN_EDIT.model.textureManager:Blit(oldTextureObj.texture, mapTexture)
                mapTextureObj.dirty = oldTextureObj.dirty
                gl.DeleteTexture(oldTextureObj.texture)
            end
        end

        SCEN_EDIT.model.textureManager.oldMapFBOTextures = {}
        stack[#stack] = nil
    end)
end

WidgetTerrainChangeTexturePushStackCommand = AbstractCommand:extends{}
WidgetTerrainChangeTexturePushStackCommand.className = "WidgetTerrainChangeTexturePushStackCommand"

function WidgetTerrainChangeTexturePushStackCommand:execute()
    SCEN_EDIT.delayGL(function()
        local stack = SCEN_EDIT.model.textureManager.stack
        table.insert(stack, SCEN_EDIT.model.textureManager.oldMapFBOTextures)
        SCEN_EDIT.model.textureManager.oldMapFBOTextures = {}
    end)
end
