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


function Shaders.CompileObject(shaderCode, shaderName)
    local shaderID = gl.CreateShader(shaderCode)
    if not shaderID then
        local shaderLog = gl.GetShaderLog(shaderID)
        Log.Error("Errors found when compiling shader: " .. tostring(shaderName))
        Log.Error(shaderLog)
        return
    end

    local shaderLog = gl.GetShaderLog(shaderID)
    if shaderLog ~= "" then
        Log.Error("Potential problems found when compiling shader: " .. tostring(shaderName))
        Log.Error(shaderLog)
	end

	local shader = {
		id = shaderID,
		uniforms = {}
	}

	for k, v in pairs(gl.GetActiveUniforms(shaderID)) do
		local uniform = {}
		for k1, v1 in pairs(v) do
			uniform[k1] = v1
		end
		uniform.id = gl.GetUniformLocation(shaderID, uniform.name)
		shader.uniforms[uniform.name] = uniform
	end

    return shader
end