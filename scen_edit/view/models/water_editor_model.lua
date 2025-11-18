WaterEditorModel = LCS.class{}

function WaterEditorModel:init()
    self.listeners = {}
end

function WaterEditorModel:AddListener(listener)
    table.insert(self.listeners, listener)
end

function WaterEditorModel:NotifyListeners(event, ...)
    for _, listener in ipairs(self.listeners) do
        if listener[event] then
            listener[event](listener, ...)
        end
    end
end

function WaterEditorModel:GetFieldDefinitions()
    return {
        {
            type = "group",
            fields = {
                {type = "boolean", name = "forceRendering", title = "Forced rendering:", tooltip = "Should the water be rendered even when minMapHeight>0.\nUse it to avoid the jumpin of the outside-map water rendering (BumpWater: endlessOcean option) when combat explosions reach groundwater.", width = 200},
                {type = "numeric", name = "numTiles", title = "NumTiles:", tooltip = "How many (squared) Tiles does the `normalTexture` have?\nSuch Tiles are used when DynamicWaves are enabled in BumpWater, the more the better.\nCheck the example php script to generate such tiled bumpmaps.", width = 200},
            }
        },
        {type = "asset", name = "normalTexture", title = "Normal texture:", tooltip = "The normal texture.", width = 250},
        {type = "separator", name = "perlin-sep", caption = "Water - perlin noise"},
        {
            type = "group",
            fields = {
                {type = "numeric", name = "perlinStartFreq", title = "Start freq:", tooltip = "The initial frequency of the bump map repetetion rate. Larger numbers mean more tiles.", width = 140},
                {type = "numeric", name = "perlinLacunarity", title = "Lacunarity:", tooltip = "How much smaller each additional repetion of the normal map should be. Larger numbers mean smaller.", width = 140},
                {type = "numeric", name = "perlinAmplitude", title = "Amplitude:", tooltip = "How strong each additional repetetion of the normal map should be", width = 140},
            }
        },
        {type = "separator", name = "water-diffuse-sep", caption = "Water - diffuse"},
        {
            type = "group",
            fields = {
                {type = "numeric", name = "diffuseFactor", title = "Factor:", tooltip = "How strong the diffuse lighting should be on the water", width = 140},
                {type = "color", name = "diffuseColor", title = "Diffuse Color:", tooltip = "The color of the diffuse lighting of the water", width = 140, format = 'rgb'},
            }
        },
        {type = "separator", name = "specular-diffuse-sep", caption = "Water - specular"},
        {
            type = "group",
            fields = {
                {type = "numeric", name = "specularFactor", title = "Factor:", tooltip = "How much light should be reflected straight from the sun", width = 140},
                {type = "numeric", name = "specularPower", title = "Power:", tooltip = "How polished the surface of the water is", width = 140},
                {type = "color", name = "specularColor", title = "Color:", tooltip = "The color of the sun reflection from the water", width = 140, format = 'rgb'},
            }
        },
        {
            type = "group",
            fields = {
                {type = "numeric", name = "ambientFactor", title = "Ambient factor:", width = 200},
            }
        },
        {type = "separator", name = "fresnel-diffuse-sep", caption = "Water - fresnel"},
        {
            type = "group",
            fields = {
                {type = "numeric", name = "fresnelMin", title = "Min:", width = 140, tooltip = "Minimum reflection strength.", min = 0, max = 1, value = 0.2},
                {type = "numeric", name = "fresnelMax", title = "Max:", width = 140, min = 0, max = 1, value = 0.8, tooltip = "Maximum reflection strength."},
                {type = "numeric", name = "fresnelPower", title = "Power:", width = 140, min = 0, max = 50, value = 4, tooltip = "Determines how fast the reflection increase with angle(viewdir,water_normal)."},
            }
        },
        {
            type = "group",
            fields = {
                {type = "numeric", name = "reflectionDistortion", title = "Reflection distortion:", width = 200},
            }
        },
        {type = "separator", name = "water-blur-sep", caption = "Water - blur"},
        {
            type = "group",
            fields = {
                {type = "numeric", name = "blurBase", title = "Base:", width = 140, tooltip = "How much should the reflection be blurred."},
                {type = "numeric", name = "blurExponent", title = "Exponent", width = 140, tooltip = "How much should the reflection be blurred."},
            }
        },
        {type = "separator", name = "water-plane-sep", caption = "Water - plane"},
        {
            type = "group",
            fields = {
                {type = "boolean", name = "hasWaterPlane", title = "Enabled:", width = 140, tooltip = "The WaterPlane is a single Quad beneath the map.\nIt should have the same color as the ocean floor to hide the map -> background boundary."},
                {type = "color", name = "planeColor", title = "Color:", width = 140, tooltip = "The WaterPlane is a single Quad beneath the map.\nIt should have the same color as the ocean floor to hide the map -> background boundary.", format = 'rgb'},
            }
        },
        {type = "separator", name = "water-waves-sep", caption = "Water - waves"},
        {
            type = "group",
            fields = {
                {type = "boolean", name = "shoreWaves", title = "Enabled:", width = 140},
                {type = "asset", name = "foamTexture", title = "Texture:", width = 250, caption = "Used for Shorewaves."},
            }
        },
        {type = "separator", name = "water-texture-sep", caption = "Water - texture"},
        {type = "asset", name = "texture", title = "Texture:", width = 250, tooltip = "`water 0` texture"},
        {
            type = "group",
            fields = {
                {type = "numeric", name = "repeatX", title = "Repeat X:", width = 140, tooltip = "`water 0` texture repeat horizontal"},
                {type = "numeric", name = "repeatY", title = "Repeat Y:", width = 140, tooltip = "`water 0` texture repeat vertical"},
            }
        },
    }
end

function WaterEditorModel:UpdateWaterRendering()
    if not gl.GetWaterRendering then
        Log.Warning("gl.GetWaterRendering missing; Update to newer engine.")
        return nil
    end

    local params = {}
    params.forceRendering = gl.GetWaterRendering("forceRendering")
    params.numTiles = gl.GetWaterRendering("numTiles")
    params.normalTexture = gl.GetWaterRendering("normalTexture")

    params.perlinStartFreq = gl.GetWaterRendering("perlinStartFreq")
    params.perlinLacunarity = gl.GetWaterRendering("perlinLacunarity")
    params.perlinAmplitude = gl.GetWaterRendering("perlinAmplitude")

    params.diffuseFactor = gl.GetWaterRendering("diffuseFactor")
    params.diffuseColor = {gl.GetWaterRendering("diffuseColor")}

    params.specularFactor = gl.GetWaterRendering("specularFactor")
    params.specularPower = gl.GetWaterRendering("specularPower")
    params.specularColor = {gl.GetWaterRendering("specularColor")}

    params.ambientFactor = gl.GetWaterRendering("ambientFactor")

    params.fresnelMin = gl.GetWaterRendering("fresnelMin")
    params.fresnelMax = gl.GetWaterRendering("fresnelMax")
    params.fresnelPower = gl.GetWaterRendering("fresnelPower")

    params.reflectionDistortion = gl.GetWaterRendering("reflectionDistortion")

    params.blurBase = gl.GetWaterRendering("blurBase")
    params.blurExponent = gl.GetWaterRendering("blurExponent")

    params.hasWaterPlane = gl.GetWaterRendering("hasWaterPlane")
    params.planeColor = {gl.GetWaterRendering("planeColor")}

    params.shoreWaves = gl.GetWaterRendering("shoreWaves")
    params.foamTexture = gl.GetWaterRendering("foamTexture")

    params.texture = gl.GetWaterRendering("texture")
    params.repeatX = gl.GetWaterRendering("repeatX")
    params.repeatY = gl.GetWaterRendering("repeatY")

    return params
end

function WaterEditorModel:OnStartChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function WaterEditorModel:OnEndChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function WaterEditorModel:OnFieldChange(name, value)
    local cmd = SetWaterParamsCommand({[name] = value})
    SB.commandManager:execute(cmd)
end
