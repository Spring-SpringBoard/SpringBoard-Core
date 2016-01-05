ModelShaders = LCS.class{}

-- TODO: be smart and so some shader-name mapping or sth
function ModelShaders:GetShader()
    if not self.shaderObj then
        self.shaderObj = self:_GetShader()
    end
    return self.shaderObj
end

function ModelShaders:GetDefaultShader()
    if not self.shaderObjDef then
        self.shaderObjDef = self:_GetDefaultShader()
    end
    return self.shaderObjDef
end

function ModelShaders:_GetDefaultShader()
    local shaderFragStr = VFS.LoadFile("shaders/ModelFragProg.glsl")
    shaderFragStr = shaderFragStr:gsub("__FRAGMENT_GLOBAL_NAMESPACE__",""):gsub("__FRAGMENT_POST_SHADING__","")
    local shaderTemplate = {
        fragment = shaderFragStr,
        uniformInt = {
            textureS3o1 = 0,
            textureS3o2 = 1,
            shadowTex   = 2,
            specularTex = 3,
            reflectTex  = 4,
            normalMap   = 5,
            --detailMap   = 6,
        },
        uniform = {
            sunPos = {gl.GetSun("pos")},
            sunAmbient = {gl.GetSun("ambient", "unit")},
            sunDiffuse = {gl.GetSun("diffuse", "unit")},
            shadowDensity = {gl.GetSun("shadowDensity" ,"unit")},
            shadowParams  = {gl.GetShadowMapParams()},
        },
        uniformMatrix = {
            shadowMatrix = {gl.GetMatrixData("shadow")},
        }
    }

    local shader = gl.CreateShader(shaderTemplate)
    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Spring.Echo(errors)
        return
    end
    local shaderObj = {
        shader = shader,
        teamColorID = gl.GetUniformLocation(shader, "teamColor")
    }
    return shaderObj
end

function ModelShaders:_GetShader()
    local shaderFragStr = VFS.LoadFile("shaders/ModelFragProg.glsl")
    shaderFragStr = shaderFragStr:gsub("__FRAGMENT_GLOBAL_NAMESPACE__",
[[
    uniform float time;
]]):gsub("__FRAGMENT_POST_SHADING__",
[[
    gl_FragColor.rgb += sin(time*4) / 3.14 / 5 + 0.1;
]])
    local shaderTemplate = {
        fragment = shaderFragStr,
        uniformInt = {
            textureS3o1 = 0,
            textureS3o2 = 1,
            shadowTex   = 2,
            specularTex = 3,
            reflectTex  = 4,
            normalMap   = 5,
            --detailMap   = 6,
        },
        uniform = {
            sunPos = {gl.GetSun("pos")},
            sunAmbient = {gl.GetSun("ambient", "unit")},
            sunDiffuse = {gl.GetSun("diffuse", "unit")},
            shadowDensity = {gl.GetSun("shadowDensity" ,"unit")},
            shadowParams  = {gl.GetShadowMapParams()},
        },
        uniformMatrix = {
            shadowMatrix = {gl.GetMatrixData("shadow")},
        }
    }

    local shader = gl.CreateShader(shaderTemplate)
    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Spring.Echo(errors)
        return
    end
    local shaderObj = {
        shader = shader,
        teamColorID = gl.GetUniformLocation(shader, "teamColor"),
        timeID = gl.GetUniformLocation(shader, "time")
    }
    return shaderObj
end