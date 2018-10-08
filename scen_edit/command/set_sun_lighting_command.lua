SetSunLightingCommand = Command:extends{}
SetSunLightingCommand.className = "SetSunLightingCommand"

function SetSunLightingCommand:init(opts)
    self.opts = opts
    self._execute_unsynced = true
    self.mergeCommand = "MergedCommand"
end

function SetSunLightingCommand:execute()
    if not self.old then
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
    end
    Spring.SetSunLighting(self.opts)
end

function SetSunLightingCommand:unexecute()
    Spring.SetSunLighting(self.old)
end
