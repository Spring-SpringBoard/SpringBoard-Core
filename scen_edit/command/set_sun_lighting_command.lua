SetSunLightingCommand = Command:extends{}
SetSunLightingCommand.className = "SetSunLightingCommand"

function SetSunLightingCommand:init(opts)
    self.className = "SetSunLightingCommand"
    self.opts = opts
    self._execute_unsynced = true
end

function SetSunLightingCommand:execute()
    self.old = {
        groundDiffuseColor  = {gl.GetSun("diffuse")},
        groundAmbientColor  = {gl.GetSun("ambient")},
        groundSpecularColor = {gl.GetSun("specular")},
        groundShadowDensity = gl.GetSun("shadowDensity"),
        unitDiffuseColor    = {gl.GetSun("diffuse", "unit")},
        unitAmbientColor    = {gl.GetSun("ambient", "unit")},
        unitSpecularColor   = {gl.GetSun("specular", "unit")},
        modelShadowDensity  = gl.GetSun("shadowDensity", "unit"),
    }
    Spring.SetSunLighting(self.opts)
end

function SetSunLightingCommand:unexecute()
    Spring.SetSunLighting(self.old)
end
