SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

LightingEditor = Editor:extends{}
Editor.Register({
    name = "lightingEditor",
    editor = LightingEditor,
    tab = "Env",
    caption = "Lighting",
    tooltip = "Edit lighting",
    image = SB_IMG_DIR .. "sunbeams.png",
    order = 0,
})

function LightingEditor:init()
    self:super("init")

    local shadowMode = Spring.GetConfigInt("Shadows")
    self:AddField(ChoiceField({
        name = "shadowMode",
        title = "Shadows:",
        tooltip = "Shadow mode. Unsynced (and unsaved) setting.",
        items = { "Off", "Terrain", "Full" },
        width = 200,
    }))
    if shadowMode == 0 then
        self.fields["shadowMode"]:Set("Off")
    elseif shadowMode == 1 then
        self.fields["shadowMode"]:Set("Full")
    elseif shadowMode == 2 then
        self.fields["shadowMode"]:Set("Terrain")
    end

    self:AddField(GroupField({
        NumericField({
            name = "sunDirX",
            title = "Dir X:",
            tooltip = "X dir",
            value = 0,
            step = 0.002,
            width = 100,
        }),
        NumericField({
            name = "sunDirY",
            title = "Dir Y:",
            tooltip = "Y dir",
            value = 0,
            step = 0.002,
            width = 100,
        }),
        NumericField({
            name = "sunDirZ",
            title = "Dir Z:",
            tooltip = "Z dir",
            value = 0,
            step = 0.002,
            width = 100,
        }),
    }))
    self:AddControl("sun-ground-sep", {
        Label:New {
            caption = "Sun ground color",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        ColorField({
            name = "groundDiffuseColor",
            title = "Diffuse:",
            tooltip = "Ground diffuse color",
            width = 100,
        }),
        ColorField({
            name = "groundAmbientColor",
            title = "Ambient:",
            tooltip = "Ground ambient color",
            width = 100,
        }),
        ColorField({
            name = "groundSpecularColor",
            title = "Specular:",
            tooltip = "Ground specular color",
            width = 100,
        }),
        NumericField({
            name = "groundShadowDensity",
            title = "Shadow density:",
            tooltip = "Ground shadow density",
            width = 100,
            minValue = 0,
            maxValue = 1,
        }),
    }))
    self:AddControl("sun-unit-sep", {
        Label:New {
            caption = "Sun unit color",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        ColorField({
            name = "unitDiffuseColor",
            title = "Diffuse:",
            tooltip = "Unit diffuse color",
            width = 100,
        }),
        ColorField({
            name = "unitAmbientColor",
            title = "Ambient:",
            tooltip = "Unit ambient color",
            width = 100,
        }),
        ColorField({
            name = "unitSpecularColor",
            title = "Specular:",
            tooltip = "Unit specular color",
            width = 100,
        }),
        NumericField({
            name = "modelShadowDensity",
            title = "Shadow density:",
            tooltip = "Unit shadow density",
            width = 100,
            minValue = 0,
            maxValue = 1,
        }),
    }))

    self:UpdateLighting()

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }

    SB.commandManager:addListener(self)

    self:Finalize(children)
end

function _ColorArrayToChannels(colorArray)
    return {r = colorArray[1], g = colorArray[2], b = colorArray[3], a = colorArray[4]}
end

function LightingEditor:UpdateLighting()
    self.updating = true

    local sunDirX, sunDirY, sunDirZ = gl.GetSun()
    self:Set("sunDirX", sunDirX)
    self:Set("sunDirY", sunDirY)
    self:Set("sunDirZ", sunDirZ)

    -- Color
    local groundDiffuse = {gl.GetSun("diffuse")}
    local groundAmbient = {gl.GetSun("ambient")}
    local groundSpecular = {gl.GetSun("specular")}
    local groundShadowDensity = gl.GetSun("shadowDensity")

    self:Set("groundDiffuseColor",  groundDiffuse)
    self:Set("groundAmbientColor",  groundAmbient)
    self:Set("groundSpecularColor", groundSpecular)
    self:Set("groundShadowDensity", groundShadowDensity)

    local unitDiffuse = {gl.GetSun("diffuse", "unit")}
    local unitAmbient = {gl.GetSun("ambient", "unit")}
    local unitSpecular = {gl.GetSun("specular", "unit")}
    local modelShadowDensity = gl.GetSun("shadowDensity", "unit")

    self:Set("unitDiffuseColor",  unitDiffuse)
    self:Set("unitAmbientColor",  unitAmbient)
    self:Set("unitSpecularColor", unitSpecular)
    self:Set("modelShadowDensity", modelShadowDensity)

    self.updating = false
end

function LightingEditor:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateLighting()
    end
end

function LightingEditor:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function LightingEditor:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function LightingEditor:OnFieldChange(name, value)
    if self.updating then
        return
    end

    if name == "shadowMode" then
        if value == "Off" then
            Spring.SendCommands("shadows 0")
        elseif value == "Terrain" then
            Spring.SendCommands("shadows 2")
        else
            Spring.SendCommands("shadows 1")
        end
    elseif name == "sunDirX" or name == "sunDirY" or name == "sunDirZ" or name == "sunStartAngle" or name == "sunOrbitTime" or name == "sunDistance" then
        value = { dirX = self.fields["sunDirX"].value,
                  dirY = self.fields["sunDirY"].value,
                  dirZ = self.fields["sunDirZ"].value,
        }
        local cmd = SetSunParametersCommand(value)
        SB.commandManager:execute(cmd)

    elseif name == "groundDiffuseColor" or name == "groundAmbientColor" or name == "groundSpecularColor" or name == "groundShadowDensity" or name == "unitAmbientColor" or name == "unitDiffuseColor" or name == "unitSunColor" or name == "modelShadowDensity" then
        local t = {}
        t[name] = value
        local cmd = SetSunLightingCommand(t)
        SB.commandManager:execute(cmd)
    end
end
