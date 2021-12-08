SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

WaterEditor = Editor:extends{}
WaterEditor:Register({
    name = "waterEditor",
    tab = "Env",
    caption = "Water",
    tooltip = "Edit water",
    image = Path.Join(SB.DIRS.IMG, 'wave-crest.png'),
    order = 2,
})

function WaterEditor:init()
    self:super("init")

    self:AddField(GroupField({
        BooleanField({
            name = "forceRendering",
            title = "Forced rendering:",
            tooltip = "Should the water be rendered even when minMapHeight>0.\nUse it to avoid the jumpin of the outside-map water rendering (BumpWater: endlessOcean option) when combat explosions reach groundwater.",
            width = 200,
        }),
        NumericField({
            name = "numTiles",
            title = "NumTiles:",
            tooltip = "How many (squared) Tiles does the `normalTexture` have?\nSuch Tiles are used when DynamicWaves are enabled in BumpWater, the more the better.\nCheck the example php script to generate such tiled bumpmaps.",
            width = 200,
        }),
    }))
    self:AddField(AssetField({
        name = "normalTexture",
        title = "Normal texture:",
        tooltip = "The normal texture.",
        width = 250,
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
            tooltip = "The initial frequency of the bump map repetetion rate. Larger numbers mean more tiles.",
            width = 140,
        }),
        NumericField({
            name = "perlinLacunarity",
            title = "Lacunarity:",
            tooltip = "How much smaller each additional repetion of the normal map should be. Larger numbers mean smaller.",
            width = 140,
        }),
        NumericField({
            name = "perlinAmplitude",
            title = "Amplitude:",
            tooltip = "How strong each additional repetetion of the normal map should be",
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
            tooltip = "How strong the diffuse lighting should be on the water",
            width = 140,
        }),
        ColorField({
            name = "diffuseColor",
            title = "Diffuse Color:",
            tooltip = "The color of the diffuse lighting of the water",
            width = 140,
            format = 'rgb',
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
            tooltip = "How much light should be reflected straight from the sun",
            width = 140,
        }),
        NumericField({
            name = "specularPower",
            title = "Power:",
            tooltip = "How polished the surface of the water is",
            width = 140,
        }),
        ColorField({
            name = "specularColor",
            title = "Color:",
            tooltip = "The color of the sun reflection from the water",
            width = 140,
            format = 'rgb',
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
            title = "Exponent",
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
            format = 'rgb',
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
        AssetField({
            name = "foamTexture",
            title = "Texture:",
            width = 250,
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
    self:AddField(AssetField({
        name = "texture",
        title = "Texture:",
        width = 250,
        tooltip = "`water 0` texture",
    }))
    self:AddField(GroupField({
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

function WaterEditor:UpdateWaterRendering()
    if not gl.GetWaterRendering then
        Log.Warning("gl.GetWaterRendering missing; Update to newer engine.")
        return
    end

    self.updating = true

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

    self.updating = false
end

function WaterEditor:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateWaterRendering()
    end
end

function WaterEditor:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function WaterEditor:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function WaterEditor:OnFieldChange(name, value)
    if self.updating then
        return
    end

    local cmd = SetWaterParamsCommand({[name] = value})
    SB.commandManager:execute(cmd)
end
