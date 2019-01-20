local shaders
local function _InitShaders()
    if shaders == nil then
        shaders = {
            diffuse = {},
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

        local shaderFragStr = VFS.LoadFile("shaders/map_drawing.glsl", nil, VFS.MOD)
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
                patternRotationID = gl.GetUniformLocation(shader, "patternRotation"),
                strengthID = gl.GetUniformLocation(shader, "strength"),
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
