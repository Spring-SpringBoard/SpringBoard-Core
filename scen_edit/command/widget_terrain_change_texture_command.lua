WidgetTerrainChangeTextureCommand = AbstractCommand:extends{}
WidgetTerrainChangeTextureCommand.className = "WidgetTerrainChangeTextureCommand"

local BIG_TEX_SIZE = 1024
function WidgetTerrainChangeTextureCommand:init(opts)
    self.className = "WidgetTerrainChangeTextureCommand"
    self.opts = opts
end

function WidgetTerrainChangeTextureCommand:execute()
    SCEN_EDIT.delayGL(function()
        self:SetTexture(self.opts)
    end)
end

function WidgetTerrainChangeTextureCommand:SetTexture(opts)
    tx = self:ApplyPen(opts)
end

function getPenShader(mode)
    if shaders == nil then
        shaders = {}
    end
    if shaders[mode] == nil then
        mapTexSQ = gl.CreateTexture(BIG_TEX_SIZE,BIG_TEX_SIZE, {
            border = false,
            min_filter = GL.LINEAR,
            mag_filter = GL.LINEAR,
            wrap_s = GL.CLAMP_TO_EDGE,
            wrap_t = GL.CLAMP_TO_EDGE,
            fbo = true, 
        })

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
            
            color = mix(min(color, (max(color,mapColor+blendFactor)-blendFactor)-blendFactor)+blendFactor,mapColor,color.a);

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

        local penShader = gl.CreateShader(shaderTemplate)
        local errors = gl.GetShaderLog(penShader)
        if errors ~= "" then
            Spring.Echo(errors)
        end
        shaders[mode] = penShader
    end

    return shaders[mode]
end

function WidgetTerrainChangeTextureCommand:ApplyPen(opts)
    local x, z = opts.x, opts.z
    local size = opts.size
    local penTexture = opts.penTexture
    local paintTexture = opts.paintTexture
    -- TODO: make this a parameter
    local texScaleX, texScaleZ = opts.texScale, opts.texScale
    local detailTexScaleX, detailTexScaleZ = opts.detailTexScale, opts.detailTexScale
    local shader = getPenShader(opts.mode)
    local blendFactor = (1 - opts.blendFactor) / 2
    local falloffFactor = opts.falloffFactor
    local diffuseColor = opts.diffuseColor

    local fs = 2
    x = x - size * (fs - falloffFactor * fs)
    z = z - size * (fs - falloffFactor * fs)
    size = size * (fs + 1 - falloffFactor * fs)

    local rT
    local texSize = BIG_TEX_SIZE

    local prefix = ""
    
    local x1ID = gl.GetUniformLocation(shader, "x1");
    local x2ID = gl.GetUniformLocation(shader, "x2");
    local z1ID = gl.GetUniformLocation(shader, "z1");
    local z2ID = gl.GetUniformLocation(shader, "z2");
    local blendFactorID = gl.GetUniformLocation(shader, "blendFactor");
    local falloffFactorID = gl.GetUniformLocation(shader, "falloffFactor");
    local diffuseColorID = gl.GetUniformLocation(shader, "diffuseColor");


    if tmp == nil then
        tmp = SCEN_EDIT.textureManager:createMapTexture()
    end
    local textures = SCEN_EDIT.textureManager:getMapTextures(x, z, x + 2 * size, z + 2 * size)
    for _, v in pairs(textures) do
        local mapTexture, _, coords = v[1], v[2], v[3]
        local dx, dz = coords[1], coords[2]

        -- copy to old texture
        SCEN_EDIT.textureManager:Blit(mapTexture, tmp)

        gl.UseShader(shader)
        gl.RenderToTexture(mapTexture,
        function()
            gl.Texture(0, tmp)
            gl.Texture(1, prefix .. penTexture)
            gl.Texture(2, prefix .. paintTexture)

            local coords = {
                dx,            dz,
                dx,            dz + 2 * size,
                dx + 2 * size, dz + 2 * size,
                dx + 2 * size, dz
            }
            local vCoord = {} -- vertex coords
            for i = 1, #coords do
                vCoord[i] = coords[i] / texSize * 2 - 1
            end

            -- map coordinates
            local mCoord = {}
            for i = 1, #coords do
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
                tCoord[i] = tCoord[i] / texSize * texScaleX
                tCoord[i+1] = tCoord[i+1] / texSize * texScaleZ
            end


            gl.Uniform(x1ID, mCoord[1])
            gl.Uniform(x2ID, mCoord[5])
            gl.Uniform(z1ID, mCoord[2])
            gl.Uniform(z2ID, mCoord[4])
            gl.Uniform(blendFactorID, blendFactor)
            gl.Uniform(falloffFactorID, falloffFactor)
            gl.Uniform(diffuseColorID, unpack(diffuseColor))

            --GL.QUADS
            -- TODO: move all this to a vertex shader?
            gl.BeginEnd(GL.QUADS, function()
                gl.MultiTexCoord(0, mCoord[1], mCoord[2])
                gl.MultiTexCoord(1, tCoord[1] * detailTexScaleX, tCoord[2] * detailTexScaleZ)
                gl.MultiTexCoord(2, tCoord[1], tCoord[2] )
                gl.Vertex(vCoord[1], vCoord[2])

                gl.MultiTexCoord(0, mCoord[3], mCoord[4])
                gl.MultiTexCoord(1, tCoord[3] * detailTexScaleX, tCoord[4] * detailTexScaleZ)
                gl.MultiTexCoord(2, tCoord[3], tCoord[4] )
                gl.Vertex(vCoord[3], vCoord[4])

                gl.MultiTexCoord(0, mCoord[5], mCoord[6])
                gl.MultiTexCoord(1, tCoord[5] * detailTexScaleX, tCoord[6] * detailTexScaleZ)
                gl.MultiTexCoord(2, tCoord[5], tCoord[6] )
                gl.Vertex(vCoord[5], vCoord[6]) 

                gl.MultiTexCoord(0, mCoord[7], mCoord[8])
                gl.MultiTexCoord(1, tCoord[7] * detailTexScaleX, tCoord[8] * detailTexScaleZ)
                gl.MultiTexCoord(2, tCoord[7], tCoord[8] )
                gl.Vertex(vCoord[7], vCoord[8])
            end)
        end)

        gl.Texture(0, false)
        gl.Texture(1, false)
        gl.Texture(2, false)
        rT = tex

        local errors = gl.GetShaderLog(shader)
        if errors ~= "" then
            Spring.Echo(errors)
        end
        gl.UseShader(0)
    end

    return rT
end

WidgetUndoTerrainChangeTextureCommand = AbstractCommand:extends{}
WidgetUndoTerrainChangeTextureCommand.className = "WidgetUndoTerrainChangeTextureCommand"

function WidgetUndoTerrainChangeTextureCommand:execute()
    SCEN_EDIT.delayGL(function()
        local stack = SCEN_EDIT.textureManager.stack
        SCEN_EDIT.textureManager.oldMapFBOTextures = stack[#stack]

        for i, v in pairs(SCEN_EDIT.textureManager.oldMapFBOTextures) do
            for j, oldTexture in pairs(v) do
                local mapTexture = SCEN_EDIT.textureManager.mapFBOTextures[i][j]
                SCEN_EDIT.textureManager:Blit(oldTexture, mapTexture)
            end
        end

        SCEN_EDIT.textureManager.oldMapFBOTextures = {}
        stack[#stack] = nil
    end)
end

WidgetTerrainChangeTexturePushStackCommand = AbstractCommand:extends{}
WidgetTerrainChangeTexturePushStackCommand.className = "WidgetTerrainChangeTexturePushStackCommand"

function WidgetTerrainChangeTexturePushStackCommand:execute()
    SCEN_EDIT.delayGL(function()
        local stack = SCEN_EDIT.textureManager.stack
        table.insert(stack, SCEN_EDIT.textureManager.oldMapFBOTextures)
        SCEN_EDIT.textureManager.oldMapFBOTextures = {}
    end)
end
