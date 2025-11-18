SkyEditorModel = LCS.class{}

function SkyEditorModel:init()
end

function SkyEditorModel:GetFieldDefinitions()
    return {
        {
            type = "group",
            fields = {
                {type = "color", name = "sunColor", title = "Sun:", tooltip = "Sun color", width = 140, format = 'rgb'},
                {type = "color", name = "skyColor", title = "Sky:", tooltip = "Sky color", width = 140, format = 'rgb'},
                {type = "color", name = "cloudColor", title = "Cloud:", tooltip = "Cloud color (requires AdvSky)", width = 140, format = 'rgb'},
            }
        },
        {type = "asset", name = "skyboxTexture", title = "Skybox:", tooltip = "Skybox texture (requires SkyBox sky)", rootDir = "skyboxes/"},
        {type = "separator", name = "atmosphere-fog-sep", caption = "Fog"},
        {
            type = "group",
            fields = {
                {type = "color", name = "fogColor", title = "Color:", tooltip = "Fog color", width = 100, format = 'rgb'},
                {type = "numeric", name = "fogStart", title = "Start:", tooltip = "Fog start", width = 140, min = 0, max = 1},
                {type = "numeric", name = "fogEnd", title = "End:", tooltip = "Fog end", width = 140, min = 0, max = 1},
            }
        },
    }
end

function SkyEditorModel:UpdateAtmosphere()
    local params = {}
    params.fogStart = gl.GetAtmosphere("fogStart")
    params.fogEnd = gl.GetAtmosphere("fogEnd")
    params.fogColor = {gl.GetAtmosphere("fogColor")}
    params.skyColor = {gl.GetAtmosphere("skyColor")}
    params.sunColor = {gl.GetAtmosphere("sunColor")}
    params.cloudColor = {gl.GetAtmosphere("cloudColor")}
    return params
end

function SkyEditorModel:OnStartChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function SkyEditorModel:OnEndChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function SkyEditorModel:OnFieldChange(name, value)
    if name == "skyboxTexture" then
        SB.delayGL(function()
            Spring.SetSkyBoxTexture(value)
        end)
    else
        local t = {}
        t[name] = value
        local cmd = SetAtmosphereCommand(t)
        SB.commandManager:execute(cmd)
    end
end
