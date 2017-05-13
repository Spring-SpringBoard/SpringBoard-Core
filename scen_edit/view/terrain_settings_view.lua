SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "editor_view.lua")
TerrainSettingsView = EditorView:extends{}

function TerrainSettingsView:init()
    self:super("init")

    self.initializing = true

    self:AddField(FileField({
        name = "detailTexture",
        title = "Detail:",
        tooltip = "Detail texture",
        value = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/detail",
    }))

    self:AddControl("sun-sep", {
        Label:New {
            caption = "Sun",
        },
        Line:New {
            x = 50,
        }
    })
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

--     self:AddControl("sun-unit-sep", {
--         Label:New {
--             caption = "Sun unit color",
--         },
--         Line:New {
--             x = 150,
--         }
--     })
--     self:AddField(GroupField({
--         ColorField({
--             name = "unitDiffuseColor",
--             title = "Diffuse:",
--             tooltip = "Unit diffuse color",
--             width = 140,
--         }),
--         ColorField({
--             name = "unitAmbientColor",
--             title = "Ambient:",
--             tooltip = "Unit ambient color",
--             width = 140,
--         }),
--         ColorField({
--             name = "unitSpecularColor",
--             title = "Specular:",
--             tooltip = "Unit specular color",
--             width = 140,
--         }),
--     }))

    --     self:AddField(GroupField({
--         NumericField({
--             name = "sunDistance",
--             title = "Sun distance:",
--             tooltip = "Sun distance",
--             value = 0,
--             step = 0.002,
--             width = 140,
--             minValue = -1,
--             maxValue = 1,
--         }),
--         NumericField({
--             name = "sunStartAngle",
--             title = "Start angle:",
--             tooltip = "Sun start angle",
--             value = 0,
--             step = 0.002,
--             width = 140,
--         }),
--         NumericField({
--             name = "sunOrbitTime",
--             title = "Orbit time:",
--             tooltip = "Sun orbit time",
--             value = 0,
--             step = 0.002,
--             width = 100,
--         }),
--     }))
    self:UpdateSun()

    self:AddControl("atmosphere-sep", {
        Label:New {
            caption = "Atmosphere color",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        ColorField({
            name = "sunColor",
            title = "Sun:",
            tooltip = "Sun color",
            width = 140,
        }),
        ColorField({
            name = "skyColor",
            title = "Sky:",
            tooltip = "Sky color",
            width = 140,
        }),
        ColorField({
            name = "cloudColor",
            title = "Cloud:",
            tooltip = "Cloud color (requires AdvSky)",
            width = 140,
        }),
    }))
    self:AddField(FileField({
        name = "skyboxTexture",
        title = "Skybox:",
        tooltip = "Skybox texture (requires SkyBox sky)",
        value = SCEN_EDIT_IMG_DIR .. "resources/skyboxes",
    }))

    self:AddControl("atmosphere-fog-sep", {
        Label:New {
            caption = "Fog",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        ColorField({
            name = "fogColor",
            title = "Color:",
            tooltip = "Fog color",
            width = 100,
        }),
        NumericField({
            name = "fogStart",
            title = "Start:",
            tooltip = "Fog start",
            width = 140,
            minValue = 0,
            maxValue = 1,
        }),
        NumericField({
            name = "fogEnd",
            title = "End:",
            tooltip = "Fog end",
            width = 140,
            minValue = 0,
            maxValue = 1,
        }),
    }))
    self:UpdateAtmosphere()

    self:AddControl("water-sun-sep", {
        Line:New {
            x = 150,
        }
    })

    self:AddControl("water-sep", {
        Label:New {
            caption = "Water",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        BooleanField({
            name = "forceRendering",
            title = "Forced rendering:",
            tooltip = "Should the water be rendered even when minMapHeight>0.\nUse it to avoid the jumpin of the outside-map water rendering (BumpWater: endlessOcean option) when combat explosions reach groundwater.",
            width = 140,
        }),
        NumericField({
            name = "numTiles",
            title = "Ambient:",
            tooltip = "How many Tiles does the `normalTexture` have?\nSuch Tiles are used when DynamicWaves are enabled in BumpWater, the more the better.\nCheck the example php script to generate such tiled bumpmaps.",
            width = 140,
        }),
        TextureField({
            name = "normalTexture",
            title = "Normal texture:",
            tooltip = "The normal texture.",
            width = 140,
        }),
    }))
    self:AddControl("perlin-sep", {
        Label:New {
            caption = "Water - perlin noise",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "perlinStartFreq",
            title = "Start freq:",
            tooltip = "Scales the normal texture.",
            width = 140,
        }),
        NumericField({
            name = "perlinLacunarity",
            title = "Lacunarity:",
            tooltip = "Scales the normal texture.",
            width = 140,
        }),
        NumericField({
            name = "perlinAmplitude",
            title = "Amplitude:",
            tooltip = "Scales the normal texture.",
            width = 140,
        }),
    }))
    self:AddControl("water-diffuse-sep", {
        Label:New {
            caption = "Water - diffuse",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "diffuseFactor",
            title = "Factor:",
            width = 140,
        }),
        ColorField({
            name = "diffuseColor",
            title = "Lacunarity:",
            width = 140,
        }),
    }))

    self:AddControl("specular-diffuse-sep", {
        Label:New {
            caption = "Water - specular",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "specularFactor",
            title = "Factor:",
            width = 140,
        }),
        NumericField({
            name = "specularPower",
            title = "Power:",
            width = 140,
        }),
        ColorField({
            name = "specularColor",
            title = "Color:",
            width = 140,
        }),
    }))

    self:AddField(GroupField({
        NumericField({
            name = "ambientFactor",
            title = "Ambient factor:",
            width = 200,
        }),
    }))

    self:AddControl("fresnel-diffuse-sep", {
        Label:New {
            caption = "Water - fresnel",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "fresnelMin",
            title = "Min:",
            width = 140,
            tooltip = "Minimum reflection strength.",
            minValue = 0,
            maxValue = 1,
            value    = 0.2,
        }),
        NumericField({
            name = "fresnelMax",
            title = "Max:",
            width = 140,
            minValue = 0,
            maxValue = 1,
            value    = 0.8,
            tooltip = "Maximum reflection strength.",
        }),
        NumericField({
            name = "fresnelPower",
            title = "Power:",
            width = 140,
            minValue = 0,
            maxValue = 50,
            value    = 4,
            tooltip = "Determines how fast the reflection increase with angle(viewdir,water_normal).",
        }),
    }))

    self:AddField(GroupField({
        NumericField({
            name = "reflectionDistortion",
            title = "Reflection distortion:",
            width = 200,
        }),
    }))

    self:AddControl("water-blur-sep", {
        Label:New {
            caption = "Water - blur",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "blurBase",
            title = "Base:",
            width = 140,
            tooltip = "How much should the reflection be blurred.",
        }),
        NumericField({
            name = "blurExponent",
            title = "Lacunarity:",
            width = 140,
            tooltip = "How much should the reflection be blurred.",
        }),
    }))

    self:AddControl("water-plane-sep", {
        Label:New {
            caption = "Water - plane",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        BooleanField({
            name = "hasWaterPlane",
            title = "Enabled:",
            width = 140,
            tooltip = "The WaterPlane is a single Quad beneath the map.\nIt should have the same color as the ocean floor to hide the map -> background boundary.",
        }),
        ColorField({
            name = "planeColor",
            title = "Color:",
            width = 140,
            tooltip = "The WaterPlane is a single Quad beneath the map.\nIt should have the same color as the ocean floor to hide the map -> background boundary.",
        }),
    }))

    self:AddControl("water-waves-sep", {
        Label:New {
            caption = "Water - waves",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        BooleanField({
            name = "shoreWaves",
            title = "Enabled:",
            width = 140,
        }),
        TextureField({
            name = "foamTexture",
            title = "Texture:",
            width = 140,
            caption = "Used for Shorewaves.",
        }),
    }))

    self:AddControl("water-texture-sep", {
        Label:New {
            caption = "Water - texture",
        },
        Line:New {
            x = 150,
        }
    })
    self:AddField(GroupField({
        TextureField({
            name = "texture",
            title = "Texture:",
            width = 140,
            tooltip = "`water 0` texture",
        }),
        NumericField({
            name = "repeatX",
            title = "Repeat X:",
            width = 140,
            tooltip = "`water 0` texture repeat horizontal",
        }),
        NumericField({
            name = "repeatY",
            title = "Repeat Y:",
            width = 140,
            tooltip = "`water 0` texture repeat vertical",
        }),
    }))

    self:UpdateWaterRendering()

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 10,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }

    self:Finalize(children)
    self.initializing = false
end

function _ColorArrayToChannels(colorArray)
    return {r = colorArray[1], g = colorArray[2], b = colorArray[3], a = colorArray[4]}
end

function TerrainSettingsView:UpdateSun()
    -- Direction
    local sunDirX, sunDirY, sunDirZ = gl.GetSun()
--     local sunDirX, sunDirY, sunDirZ, sunDistance, sunStartAngle, sunOrbitTime = gl.GetSun()
    self:Set("sunDirX", sunDirX)
    self:Set("sunDirY", sunDirY)
    self:Set("sunDirZ", sunDirZ)
    self.dynamicSunEnabled = false
--     if sunStartAngle then
--         -- FIXME: distance is wrong, not usable atm
-- --         self.dynamicSunEnabled = true
--         self:Set("sunDistance", sunDistance)
--         self:Set("sunStartAngle", sunStartAngle)
--         self:Set("sunOrbitTime", sunOrbitTime)
--     end

    -- Color
    local groundDiffuse = {gl.GetSun("diffuse")}
    local groundAmbient = {gl.GetSun("ambient")}
    local groundSpecular = {gl.GetSun("specular")}
    local groundShadowDensity = gl.GetSun("shadowDensity")
--     groundDiffuse[4] = 1
--     groundAmbient[4] = 1
--     groundSpecular[4] = 1
    self:Set("groundDiffuseColor",  groundDiffuse)
    self:Set("groundAmbientColor",  groundAmbient)
    self:Set("groundSpecularColor", groundSpecular)
    self:Set("groundShadowDensity", groundShadowDensity)

    local unitDiffuse = {gl.GetSun("diffuse", "unit")}
    local unitAmbient = {gl.GetSun("ambient", "unit")}
    local unitSpecular = {gl.GetSun("specular", "unit")}
    local modelShadowDensity = gl.GetSun("shadowDensity", "unit")
--     unitDiffuse[4] = 1
--     unitAmbient[4] = 1
--     unitSpecular[4] = 1
    self:Set("unitDiffuseColor",  unitDiffuse)
    self:Set("unitAmbientColor",  unitAmbient)
    self:Set("unitSpecularColor", unitSpecular)
    self:Set("modelShadowDensity", modelShadowDensity)
end

function TerrainSettingsView:UpdateAtmosphere()
    self:Set("fogStart",   gl.GetAtmosphere("fogStart"))
    self:Set("fogEnd",     gl.GetAtmosphere("fogEnd"))
    self:Set("fogColor",   {gl.GetAtmosphere("fogColor")})
    self:Set("skyColor",   {gl.GetAtmosphere("skyColor")})
--     self:Set("skyDir",     gl.GetAtmosphere("skyDir"))
    self:Set("sunColor",   {gl.GetAtmosphere("sunColor")})
    self:Set("cloudColor", {gl.GetAtmosphere("cloudColor")})
end

function TerrainSettingsView:UpdateWaterRendering()
    if not gl.GetWaterRendering then
        Log.Warning("gl.GetWaterRendering missing; Update to newer engine.")
        return
    end

    self:Set("forceRendering", gl.GetWaterRendering("forceRendering"))
    self:Set("numTiles", gl.GetWaterRendering("numTiles"))
    self:Set("normalTexture", gl.GetWaterRendering("normalTexture"))

    self:Set("perlinStartFreq", gl.GetWaterRendering("perlinStartFreq"))
    self:Set("perlinLacunarity", gl.GetWaterRendering("perlinLacunarity"))
    self:Set("perlinAmplitude", gl.GetWaterRendering("perlinAmplitude"))

    self:Set("diffuseFactor", gl.GetWaterRendering("diffuseFactor"))
    self:Set("diffuseColor", {gl.GetWaterRendering("diffuseColor")})

    self:Set("specularFactor", gl.GetWaterRendering("specularFactor"))
    self:Set("specularPower", gl.GetWaterRendering("specularPower"))
    self:Set("specularColor", {gl.GetWaterRendering("specularColor")})

    self:Set("ambientFactor", gl.GetWaterRendering("ambientFactor"))

    self:Set("fresnelMin", gl.GetWaterRendering("fresnelMin"))
    self:Set("fresnelMax", gl.GetWaterRendering("fresnelMax"))
    self:Set("fresnelPower", gl.GetWaterRendering("fresnelPower"))

    self:Set("reflectionDistortion", gl.GetWaterRendering("reflectionDistortion"))

    self:Set("blurBase", gl.GetWaterRendering("blurBase"))
    self:Set("blurExponent", gl.GetWaterRendering("blurExponent"))

    self:Set("hasWaterPlane", gl.GetWaterRendering("hasWaterPlane"))
    self:Set("planeColor", {gl.GetWaterRendering("planeColor")})

    self:Set("shoreWaves", gl.GetWaterRendering("shoreWaves"))
    self:Set("foamTexture", gl.GetWaterRendering("foamTexture"))

    self:Set("texture", gl.GetWaterRendering("texture"))
    self:Set("repeatX", gl.GetWaterRendering("repeatX"))
    self:Set("repeatY", gl.GetWaterRendering("repeatY"))
end

function TerrainSettingsView:OnStartChange(name)
    SCEN_EDIT.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function TerrainSettingsView:OnEndChange(name)
    SCEN_EDIT.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function TerrainSettingsView:OnFieldChange(name, value)
    if self.initializing then
        return
    end

    if name == "detailTexture" then
        SCEN_EDIT.delayGL(function()
--             Log.Debug(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_2D)
--
--             local tex = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
-- 						target = 0x8513,
--                 min_filter = GL.LINEAR,
--                 mag_filter = GL.LINEAR,
--                 fbo = true,
--             })
-- 					gl.Texture(item)
--             Log.Debug(texInfo.xsize, texInfo.ysize, item)
--             SCEN_EDIT.model.textureManager:Blit(item, tex)
            local texInfo = gl.TextureInfo(value)
            gl.DeleteTexture(value)
            gl.Texture(value)
            Spring.SetMapShadingTexture("$detail", value)
        end)

    elseif name == "skyboxTexture" then
        SCEN_EDIT.delayGL(function()
--             Log.Debug(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_2D)
--
--             local tex = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
--                 target = 0x8513,
--                 min_filter = GL.LINEAR,
--                 mag_filter = GL.LINEAR,
--                 fbo = true,
--             })
--             gl.Texture(item)
--             Log.Debug(texInfo.xsize, texInfo.ysize, item)
--             SCEN_EDIT.model.textureManager:Blit(item, tex)
            local texInfo = gl.TextureInfo(value)
            Spring.SetSkyBoxTexture(value)
        end)

    elseif name == "sunDirX" or name == "sunDirY" or name == "sunDirZ" or name == "sunStartAngle" or name == "sunOrbitTime" or name == "sunDistance" then
        value = { dirX = self.fields["sunDirX"].value,
                  dirY = self.fields["sunDirY"].value,
                  dirZ = self.fields["sunDirZ"].value,
--                   distance = self.fields["sunDistance"].value,
--                   startAngle = self.fields["sunStartAngle"].value,
--                   orbitTime = self.fields["sunOrbitTime"].value,
        }
--         if not self.dynamicSunEnabled then
--             value.distance = nil
--             value.startAngle = nil
--             value.orbitTime = nil
--         end
        local cmd = SetSunParametersCommand(value)
        SCEN_EDIT.commandManager:execute(cmd)

    elseif name == "groundDiffuseColor" or name == "groundAmbientColor" or name == "groundSpecularColor" or name == "groundShadowDensity" or name == "unitAmbientColor" or name == "unitDiffuseColor" or name == "unitSunColor" or name == "modelShadowDensity" then
        local t = {}
        t[name] = value
        local cmd = SetSunLightingCommand(t)
        SCEN_EDIT.commandManager:execute(cmd)

    elseif name == "fogColor" or name == "skyColor" or name == "skyDir" or name == "sunColor" or name == "cloudColor" or name == "fogStart" or name == "fogEnd" then
        local t = {}
        t[name] = value
        local cmd = SetAtmosphereCommand(t)
        SCEN_EDIT.commandManager:execute(cmd)
    else
        local cmd = SetWaterParamsCommand({[name] = value})
        SCEN_EDIT.commandManager:execute(cmd)
    end
end
