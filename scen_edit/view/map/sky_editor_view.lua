SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

SkyEditorView = EditorView:extends{}

function SkyEditorView:init()
    self:super("init")

    self.initializing = true

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
    self:AddField(AssetField({
        name = "skyboxTexture",
        title = "Skybox:",
        tooltip = "Skybox texture (requires SkyBox sky)",
        rootDir = "skyboxes/",
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
    self.initializing = false

    SB.commandManager:addListener(self)
end

function _ColorArrayToChannels(colorArray)
    return {r = colorArray[1], g = colorArray[2], b = colorArray[3], a = colorArray[4]}
end

function SkyEditorView:UpdateAtmosphere()
    self.updating = true

    self:Set("fogStart",   gl.GetAtmosphere("fogStart"))
    self:Set("fogEnd",     gl.GetAtmosphere("fogEnd"))
    self:Set("fogColor",   {gl.GetAtmosphere("fogColor")})
    self:Set("skyColor",   {gl.GetAtmosphere("skyColor")})
--     self:Set("skyDir",     gl.GetAtmosphere("skyDir"))
    self:Set("sunColor",   {gl.GetAtmosphere("sunColor")})
    self:Set("cloudColor", {gl.GetAtmosphere("cloudColor")})

    self.updating = false
end

function SkyEditorView:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateAtmosphere()
    end
end

function SkyEditorView:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function SkyEditorView:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function SkyEditorView:OnFieldChange(name, value)
    if self.initializing or self.updating then
        return
    end

    if name == "skyboxTexture" then
        SB.delayGL(function()
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
    --             SB.model.textureManager:Blit(item, tex)
            local texInfo = gl.TextureInfo(value)
            Spring.SetSkyBoxTexture(value)
        end)
    else
        local t = {}
        t[name] = value
        local cmd = SetAtmosphereCommand(t)
        SB.commandManager:execute(cmd)
    end
end
