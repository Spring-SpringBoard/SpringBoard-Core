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

function ModelShaders:_GetShaderFiles()
    return {
        vertex = VFS.LoadFile("shaders/ModelVertProg.glsl"),
        fragment = VFS.LoadFile("shaders/ModelFragProg.glsl"),
    }
end

function ModelShaders:_CompileShader(programs)
    local shaderTemplate = {
        vertex   = programs.vertex,
        fragment = programs.fragment,
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
            sunDir = {gl.GetSun("pos")},
            sunAmbient = {gl.GetSun("ambient", "unit")},
            sunDiffuse = {gl.GetSun("diffuse", "unit")},
            shadowDensity = {gl.GetSun("shadowDensity" ,"unit")},
            shadowParams  = {gl.GetShadowMapParams()},

            cameraPos = {Spring.GetCameraPosition()},
        },
        uniformMatrix = {
            shadowMatrix = {gl.GetMatrixData("shadow")},
        }
    }

    local shader = Shaders.Compile(shaderTemplate, "ModelShader")
    if not shader then
        return
    end
    local shaderObj = {
        shader = shader,
        teamColorID = gl.GetUniformLocation(shader, "teamColor")
    }
    return shaderObj
end

function ModelShaders:_GetDefaultShader()
    local shaderFiles = self:_GetShaderFiles()
    local shaderVertexStr = shaderFiles.vertex
    local shaderFragStr = shaderFiles.fragment
    shaderFragStr = shaderFragStr:gsub("__FRAGMENT_GLOBAL_NAMESPACE__",""):gsub("__FRAGMENT_POST_SHADING__","")
    return self:_CompileShader({vertex = shaderVertexStr, fragment = shaderFragStr})
end

function ModelShaders:_GetShader()
    local shaderFiles = self:_GetShaderFiles()
    local shaderVertexStr = shaderFiles.vertex
    local shaderFragStr = shaderFiles.fragment
    shaderFragStr = shaderFragStr:gsub("__FRAGMENT_GLOBAL_NAMESPACE__",
[[
    uniform float time;
]]):gsub("__FRAGMENT_POST_SHADING__",
[[
    gl_FragColor.rgb += sin(time*4.0) / 3.14 / 5.0 + 0.1;
]])
    local obj = self:_CompileShader({vertex = shaderVertexStr, fragment = shaderFragStr})
    obj.timeID = gl.GetUniformLocation(obj.shader, "time")
    return obj
end
