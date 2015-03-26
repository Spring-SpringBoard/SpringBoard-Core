WidgetTerrainChangeTextureCommand = UndoableCommand:extends{}
WidgetTerrainChangeTextureCommand.className = "WidgetTerrainChangeTextureCommand"

local BIG_TEX_SIZE = 1024
function WidgetTerrainChangeTextureCommand:init(x, z, size, textureName, paintTexture, undo)
    self.className = "WidgetTerrainChangeTextureCommand"
    self.x, self.z, self.size = x, z, size
    self.textureName = textureName
    self.paintTexture = paintTexture
    self.undo = undo
end

function WidgetTerrainChangeTextureCommand:execute()
    SCEN_EDIT.delayGL(function()
        if self.undo then
            self:unexecute()
            return
        end
        self:SetTexture(self.x, self.z, self.size, self.textureName, self.paintTexture)
    end)
end

function WidgetTerrainChangeTextureCommand:unexecute()
    local textures = SCEN_EDIT.textureManager:getMapTextures(self.x, self.z, 
        self.x + 2 * self.size, self.z + 2 * self.size)
    for _, v in pairs(textures) do
        local mapTexture, oldTexture, coords = v[1], v[2], v[3]
        SCEN_EDIT.textureManager:Blit(oldTexture, mapTexture)
    end

end

function WidgetTerrainChangeTextureCommand:SetTexture(x, z, size, penTexture, paintTexture)
    tx = self:ApplyPen(x, z, size, penTexture, paintTexture)
end


function getPenShader()
    if penShader == nil then
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
            ["BlendNormal"] = [[mix(penColor,mapColor,penColor.a);]],

            ["BlendAdd"] = [[mix((mapColor+penColor),mapColor,penColor.a);]],

            ["BlendColorBurn"] = [[mix(1.0-(1.0-mapColor)/penColor,mapColor,penColor.a);]],

            ["BlendColorDodge"] = [[mix(mapColor/(1.0-penColor),mapColor,penColor.a);]],

            ["BlendColor"] = [[mix(sqrt(dot(mapColor.rgb,mapColor.rgb)) * normalize(penColor),mapColor,penColor.a);]],

            ["BlendDarken"] = [[mix(min(mapColor,penColor),mapColor,penColor.a);]],

            ["BlendDifference"] = [[mix(abs(penColor-mapColor),mapColor,penColor.a);]],

            ["BlendExclusion"] = [[mix(penColor+mapColor-(2.0*penColor*mapColor),mapColor,penColor.a);]],

            ["BlendHardLight"] = [[mix(lerp(2.0 * mapColor * penColor,1.0 - 2.0*(1.0-penColor)*(1.0-mapColor),min(1.0,max(0.0,10.0*(dot(vec4(0.25,0.65,0.1,0.0),penColor)- 0.45)))),mapColor,penColor.a);]],

            ["BlendInverseDifference"] = [[mix(1.0-abs(mapColor-penColor),mapColor,penColor.a);]],

            ["BlendLighten"] = [[mix(max(penColor,mapColor),mapColor,penColor.a);]],

            ["BlendLuminance"] = [[mix(dot(penColor,vec4(0.25,0.65,0.1,0.0))*normalize(mapColor),mapColor,penColor.a);]],

            ["BlendMultiply"] = [[mix(penColor*mapColor,mapColor,penColor.a);]],

            ["BlendOverlay"] = [[mix(lerp(2.0 * mapColor * penColor,1.0 - 2.0*(1.0-penColor)*(1.0-mapColor),min(1.0,max(0.0,10.0*(dot(vec4(0.25,0.65,0.1,0.0),mapColor)- 0.45)))),mapColor,penColor.a);]],

            ["BlendPremultiplied"] = [[vec4(penColor.rgb + (1.0-penColor.a)*mapColor.rgb, (penColor.a+mapColor.a));]],

            ["BlendScreen"] = [[mix(1.0-(1.0-mapColor)*(1.0-penColor),mapColor,penColor.a);]],

            ["BlendSoftLight"] = [[mix(2.0*mapColor*penColor+mapColor*mapColor-2.0*mapColor*mapColor*penColor,mapColor,penColor.a);]],

            ["BlendSubtract"] = [[mix(mapColor-penColor,mapColor,penColor.a);]],

            ["BlendUnmultiplied"] = [[mix(penColor,mapColor,penColor.a);]],

            ["BlendRAW"] = [[penColor;]], --//TODO make custom shaders for specular textures
        }

        local shaderFragStr = [[                    

        uniform sampler2D mapTex;
        uniform sampler2D penTex;
        uniform sampler2D paintTex;
        uniform float multiplier;
        
        uniform float x1, x2, z1, z2;

        vec4 mix(vec4 penColor, vec4 mapColor, float alpha) {
            return vec4(penColor.rgb * alpha + mapColor.rgb * (1.0 - alpha), 1.0);
        }

        void main(void)
        {
            vec4 mapColor = texture2D(mapTex, gl_TexCoord[0].st);
            vec4 penColor = texture2D(penTex, gl_TexCoord[1].st);
            vec4 texColor = texture2D(paintTex, gl_TexCoord[2].st);
            
            vec4 color = (gl_Color * texColor * penColor);

            // calculate alpha (smaller the further away it is)
            vec2 size = vec2(x2 - x1, z2 - z1);
            vec2 center = size / 2;
            vec2 delta = (gl_TexCoord[0].xy - vec2(x1, z1) - center) / size;
            float distance = sqrt(delta.x * delta.x + delta.y * delta.y);
            float alpha = color.a * (1 - 2 * distance);
            alpha = clamp(alpha, 0, 1);

            color = mix(color, mapColor, alpha);
            if (multiplier < 0) {
                color = mix(color,mapColor,(1 - color.a));
            }

            gl_FragColor = color;
        }
        ]]
        local shaderTemplate = {
            fragment = string.format(shaderFragStr,penBlenders["BlendRAW"]),
            uniformInt = {
                mapTex = 0,
                penTex = 1,
                paintTex = 2,
            },
        }

        penShader = gl.CreateShader(shaderTemplate)
        local errors = gl.GetShaderLog(penShader)
        if errors ~= "" then
            Spring.Echo(errors)
        end
    end

    return penShader
end

function getOldTexture()
    local texSize = BIG_TEX_SIZE
    if oldTexture == nil then
        oldTexture = SCEN_EDIT.textureManager:createMapTexture()
    end
    return oldTexture
end

function WidgetTerrainChangeTextureCommand:ApplyPen(x, z, size, penTexture, paintTexture)    
    local rT
    local texSize = BIG_TEX_SIZE

    local prefix = ""

    local multiplier = gl.GetUniformLocation(getPenShader(), "multiplier");
    
    local x1ID = gl.GetUniformLocation(getPenShader(), "x1");
    local x2ID = gl.GetUniformLocation(getPenShader(), "x2");
    local z1ID = gl.GetUniformLocation(getPenShader(), "z1");
    local z2ID = gl.GetUniformLocation(getPenShader(), "z2");

    local tmp = getOldTexture()
    local textures = SCEN_EDIT.textureManager:getMapTextures(x, z, x + 2 * size, z + 2 * size)
    for _, v in pairs(textures) do
        local mapTexture, oldTexture, coords = v[1], v[2], v[3]
        local dx, dz = coords[1], coords[2]

        -- copy to old texture
        SCEN_EDIT.textureManager:Blit(mapTexture, tmp)

        gl.UseShader(getPenShader())
        gl.RenderToTexture(mapTexture,
        function()
            if self.undo then
                gl.Uniform(multiplier, -1)
            else
                gl.Uniform(multiplier, 1)
            end
            gl.Texture(0, tmp)
            gl.Texture(1, prefix .. penTexture)
            gl.Texture(2, prefix .. paintTexture)
            
            -- TODO: make this a parameter
            local texScaleX, texScaleZ = 3, 3
            local detailTexScaleX, detailTexScaleZ = math.pi, math.pi
            
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

            local tCoord = {} -- texture coords
            for i = 1, #vCoord do
                tCoord[i] = coords[i] / texSize
            end
            
            gl.Uniform(x1ID, tCoord[1])
            gl.Uniform(x2ID, tCoord[5])
            gl.Uniform(z1ID, tCoord[2])
            gl.Uniform(z2ID, tCoord[4])

            --GL.QUADS
            -- TODO: move all this to a vertex shader?
            gl.BeginEnd(GL.QUADS, function()
                gl.MultiTexCoord(0, tCoord[1], tCoord[2])
                gl.MultiTexCoord(1, tCoord[1] * detailTexScaleX, tCoord[2] * detailTexScaleZ)
                gl.MultiTexCoord(2, tCoord[1] * texScaleX, tCoord[2] * texScaleZ)
                gl.Vertex(vCoord[1], vCoord[2])

                gl.MultiTexCoord(0, tCoord[3], tCoord[4])
                gl.MultiTexCoord(1, tCoord[3] * detailTexScaleX, tCoord[4] * detailTexScaleZ)
                gl.MultiTexCoord(2, tCoord[3] * texScaleX, tCoord[4] * texScaleZ)
                gl.Vertex(vCoord[3], vCoord[4])

                gl.MultiTexCoord(0, tCoord[5], tCoord[6])
                gl.MultiTexCoord(1, tCoord[5] * detailTexScaleX, tCoord[6] * detailTexScaleZ)
                gl.MultiTexCoord(2, tCoord[5] * texScaleX, tCoord[6] * texScaleZ)
                gl.Vertex(vCoord[5], vCoord[6]) 

                gl.MultiTexCoord(0, tCoord[7], tCoord[8])
                gl.MultiTexCoord(1, tCoord[7] * detailTexScaleX, tCoord[8] * detailTexScaleZ)
                gl.MultiTexCoord(2, tCoord[7] * texScaleX, tCoord[8] * texScaleZ)
                gl.Vertex(vCoord[7], vCoord[8])
            end)
        end)

        gl.Texture(0, false)
        gl.Texture(1, false)
        gl.Texture(2, false)
        rT = tex

        local errors = gl.GetShaderLog(getPenShader())
        if errors ~= "" then
            Spring.Echo(errors)
        end
        gl.UseShader(0)
    end

    return rT
end