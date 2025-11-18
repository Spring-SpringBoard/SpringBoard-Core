LightingEditorModel = LCS.class{}

function LightingEditorModel:init()
end

function LightingEditorModel:GetFieldDefinitions()
    return {
        {type = "choice", name = "shadowMode", title = "Shadows:", tooltip = "Shadow mode. Unsynced (and unsaved) setting.", items = {"Off", "Terrain", "Full"}, width = 200},
        {
            type = "group",
            fields = {
                {type = "numeric", name = "sunDirX", title = "Dir X:", tooltip = "X dir", value = 0, step = 0.002, width = 100},
                {type = "numeric", name = "sunDirY", title = "Dir Y:", tooltip = "Y dir", value = 0, step = 0.002, width = 100},
                {type = "numeric", name = "sunDirZ", title = "Dir Z:", tooltip = "Z dir", value = 0, step = 0.002, width = 100},
            }
        },
        {type = "separator", name = "sun-ground-sep", caption = "Sun ground color"},
        {
            type = "group",
            fields = {
                {type = "color", name = "groundDiffuseColor", title = "Diffuse:", tooltip = "Ground diffuse color", width = 140, format = 'rgb'},
                {type = "color", name = "groundAmbientColor", title = "Ambient:", tooltip = "Ground ambient color", width = 140, format = 'rgb'},
                {type = "color", name = "groundSpecularColor", title = "Specular:", tooltip = "Ground specular color", width = 140, format = 'rgb'},
            }
        },
        {type = "numeric", name = "groundShadowDensity", title = "Shadow density:", tooltip = "Ground shadow density", width = 200, min = 0, max = 1},
        {type = "separator", name = "sun-unit-sep", caption = "Sun unit color"},
        {
            type = "group",
            fields = {
                {type = "color", name = "unitDiffuseColor", title = "Diffuse:", tooltip = "Unit diffuse color", width = 140, format = 'rgb'},
                {type = "color", name = "unitAmbientColor", title = "Ambient:", tooltip = "Unit ambient color", width = 140, format = 'rgb'},
                {type = "color", name = "unitSpecularColor", title = "Specular:", tooltip = "Unit specular color", width = 140, format = 'rgb'},
            }
        },
        {type = "numeric", name = "modelShadowDensity", title = "Shadow density:", tooltip = "Unit shadow density", width = 200, min = 0, max = 1},
    }
end

function LightingEditorModel:GetInitialShadowMode()
    local shadowMode = Spring.GetConfigInt("Shadows")
    if shadowMode == 0 then
        return "Off"
    elseif shadowMode == 1 then
        return "Full"
    elseif shadowMode == 2 then
        return "Terrain"
    end
    return "Off"
end

function LightingEditorModel:UpdateLighting()
    local params = {}

    local sunDirX, sunDirY, sunDirZ = gl.GetSun()
    params.sunDirX = sunDirX
    params.sunDirY = sunDirY
    params.sunDirZ = sunDirZ

    params.groundDiffuseColor = {gl.GetSun("diffuse")}
    params.groundAmbientColor = {gl.GetSun("ambient")}
    params.groundSpecularColor = {gl.GetSun("specular")}
    params.groundShadowDensity = gl.GetSun("shadowDensity")

    params.unitDiffuseColor = {gl.GetSun("diffuse", "unit")}
    params.unitAmbientColor = {gl.GetSun("ambient", "unit")}
    params.unitSpecularColor = {gl.GetSun("specular", "unit")}
    params.modelShadowDensity = gl.GetSun("shadowDensity", "unit")

    return params
end

function LightingEditorModel:OnStartChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function LightingEditorModel:OnEndChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function LightingEditorModel:OnFieldChange(name, value, fields)
    if name == "shadowMode" then
        if value == "Off" then
            Spring.SendCommands("shadows 0")
        elseif value == "Terrain" then
            Spring.SendCommands("shadows 2")
        else
            Spring.SendCommands("shadows 1")
        end
    elseif name == "sunDirX" or name == "sunDirY" or name == "sunDirZ" then
        value = {
            dirX = fields["sunDirX"].value,
            dirY = fields["sunDirY"].value,
            dirZ = fields["sunDirZ"].value,
        }
        local cmd = SetSunParametersCommand(value)
        SB.commandManager:execute(cmd)
    else
        local t = {}
        t[name] = value
        local cmd = SetSunLightingCommand(t)
        SB.commandManager:execute(cmd)
    end
end
