SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

TerrainSettingsEditor = Editor:extends{}
Editor.Register({
    name = "terrainSettings",
    editor = TerrainSettingsEditor,
    tab = "Map",
    caption = "Settings",
    tooltip = "Edit map settings",
    image = SB_IMG_DIR .. "globe.png",
    order = 5,
})

function TerrainSettingsEditor:init()
    self:super("init")

    self:AddField(GroupField({
        BooleanField({
            name = "voidWater",
            title = "Void water:",
            tooltip = "Determines whether ground is rendered transparent where there should be water.",
            width = 140,
        }),
        BooleanField({
            name = "voidGround",
            title = "Void ground:",
            tooltip = "Determines whether ground can be rendered transparent.",
            width = 140,
        }),
    }))

    self:AddField(BooleanField({
        name = "splatDetailNormalDiffuseAlpha",
        title = "DNTS diffuse alpha:",
        tooltip = "Whether or not DNTS texture alpha channel should be treated as a diffuse luminance.",
        width = 290,
    }))

    self:UpdateMapRendering()

    self:AddField(AssetField({
        name = "detailTexture",
        title = "Detail texture:",
        tooltip = "Detail texture",
        rootDir = "detail/",
    }))

    self:AddField(FeatureField({
        name = "ff",
        title = "Feature:",
        tooltip = "da feature field.",
    }))

    self:AddField(FeatureTypeField({
        name = "ftf",
        title = "Feature type:",
        tooltip = "da feature type field.",
    }))

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

    self:Finalize(children)
end

function _ColorArrayToChannels(colorArray)
    return {r = colorArray[1], g = colorArray[2], b = colorArray[3], a = colorArray[4]}
end

function TerrainSettingsEditor:UpdateMapRendering()
    if not gl.GetMapRendering then
        return
    end

    self:Set("voidWater", gl.GetMapRendering("voidWater"))
    self:Set("voidGround", gl.GetMapRendering("voidGround"))
    self:Set("splatDetailNormalDiffuseAlpha", gl.GetMapRendering("splatDetailNormalDiffuseAlpha"))
end

function TerrainSettingsEditor:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function TerrainSettingsEditor:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function TerrainSettingsEditor:OnFieldChange(name, value)
    if name == "detailTexture" then
        SB.delayGL(function()
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
--             SB.model.textureManager:Blit(item, tex)
            local texInfo = gl.TextureInfo(value)
            gl.DeleteTexture(value)
            gl.Texture(value)
            Spring.SetMapShadingTexture("$detail", value)
        end)
    elseif name == "voidWater" or name == "voidGround" or name == "splatDetailNormalDiffuseAlpha" then
        local t = {
            [name] = value,
        }
        local cmd = SetMapRenderingParamsCommand(t)
        SB.commandManager:execute(cmd)
    end
end
