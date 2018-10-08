Shaders = Shaders or {}
-- Depends on log.lua

function Shaders.Compile(shaderCode, shaderName)
    local shader = gl.CreateShader(shaderCode)
    if not shader then
        local shaderLog = gl.GetShaderLog(shader)
        Log.Error("Errors found when compiling shader: " .. tostring(shaderName))
        Log.Error(shaderLog)
        return
    end

    local shaderLog = gl.GetShaderLog(shader)
    if shaderLog ~= "" then
        Log.Warning("Potential problems found when compiling shader: " .. tostring(shaderName))
        Log.Warning(shaderLog)
    end

    return shader
end
