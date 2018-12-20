SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

TerrainSettingsEditor = Editor:extends{}
TerrainSettingsEditor:Register({
    name = "terrainSettings",
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

    self:_AddMapTextureControls()
    self:_AddMapCompileControls()

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

function TerrainSettingsEditor:_AddMapTextureControls()
    self:AddControl("map-textures-sep", {
        Label:New {
            caption = "Map textures",
        },
        Line:New {
            x = 150,
        }
    })
    self.mapTextures = {}
    for name, def in pairs(SB.model.textureManager.shadingTextureDefs) do
        local engineName = def.engineName
        Spring.Echo(engineName)
        local texInfo = gl.TextureInfo(engineName)
        local exists = texInfo.xsize > 0 and texInfo.ysize > 0

        local fname = "tex_" .. tostring(name)
        self.mapTextures[fname] = name
        self:AddField(BooleanField({
            name = fname,
            value = exists,
            title = String.Capitalize(name),
            tooltip = "Toggle texture enable: " .. tostring(engineName),
            width = 140,
        }))
    end
end

function TerrainSettingsEditor:_AddMapCompileControls()
    if WG.Connector == nil or VFS.GetFileAbsolutePath == nil then
        return
    end

    self:AddControl("compile-sep", {
        Label:New {
            caption = "Compile map",
        },
        Line:New {
            x = 150,
        }
    })
    self.btnCompile = Button:New ({
        caption = "Start",
        height = 30,
        width = 140,
        OnClick = {
            function()
                self.progressBar.tooltip = ""
                self.progressBar:SetCaption("")

                local heightPath = self.fields["heightPath"].value
                local diffusePath = self.fields["diffusePath"].value

                if not VFS.FileExists(heightPath, VFS.RAW) then
                    Log.Warn("Heightmap texture missing from: " .. tostring(heightPath))
                    return
                end

                if not VFS.FileExists(diffusePath, VFS.RAW) then
                    Log.Warn("Diffuse texture missing from: " .. tostring(diffusePath))
                    return
                end

                heightPath = VFS.GetFileAbsolutePath(heightPath)
                diffusePath = VFS.GetFileAbsolutePath(diffusePath)

                self.compileFolderPath = nil
                if SB.projectDir ~= nil then
                    self.compileFolderPath = Path.Join(SB_WRITE_PATH, SB.projectDir)
                else
                    self.compileFolderPath = SB_PROJECTS_ABS_DIR
                end

                local outputPath = Path.Join(self.compileFolderPath, "Compiled")
                WG.Connector.Send("CompileMap", {
                    heightPath = heightPath,
                    diffusePath = diffusePath,
                    outputPath = outputPath,
                })
            end
        }
    })
    self.progressBar = Progressbar:New ({
        x = 145,
        height = 30,
        width = 160,
        value = 0,
    })

    local exportTooltip = "You may want to export maps first."

    self:AddField(AssetField({
        name = "heightPath",
        title = "Height:",
        tooltip = "Path to height image. " .. tostring(exportTooltip),
        width = 300,
        value = SB_PROJECTS_DIR,
    }))
    self:AddField(AssetField({
        name = "diffusePath",
        title = "Diffuse:",
        tooltip = "Path to diffuse image. " .. tostring(exportTooltip),
        width = 300,
        value = SB_PROJECTS_DIR,
    }))

    self:AddField(Field({
        name = "btnCompile",
        height = 30,
        width = 400,
        components = {
            self.btnCompile,
            self.progressBar,
        }
    }))


    WG.Connector.Register("CompileMapStarted", function()
        self.progressBar:SetCaption("Starting...")
    end)

    WG.Connector.Register("CompileMapFinished", function()
        self.progressBar:SetValue(100)
        self.progressBar:SetCaption("Finished")

        WG.Connector.Send("OpenFile", {
            path = "file://" .. self.compileFolderPath,
        })
    end)

    WG.Connector.Register("CompileMapError", function(command)
        self.progressBar:SetCaption("Error")
        Log.Warning("Failed to compile: " .. tostring(command.msg))
        self.progressBar.tooltip = tostring(command.msg)
    end)

    WG.Connector.Register("CompileMapProgress", function(command)
        local current, total = command.current, command.total
        local value = current * 100 / total
        value = math.max(value, 0)
        value = math.min(value, 100)
        self.progressBar:SetValue(value)
        if self.progressBar.caption ~= "Compiling" then
            self.progressBar:SetCaption("Compiling")
        end
    end)

    -- TODO: listen on commands
    -- SB.commandManager:addListener(self)
end

--function TerrainSettingsEditor:OnCommandExecuted(cmdIDs, isUndo, isRedo, display)
-- if display == "ExportMapsCommand" and SB_EXPORTED_TO ~= nil then
function TerrainSettingsEditor:UpdateCompilePaths(folderPath)
    self:Set("heightPath", Path.Join(folderPath, "heightmap.png"))
    self:Set("diffusePath", Path.Join(folderPath, "diffuse.png"))
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
--                         target = 0x8513,
--                 min_filter = GL.LINEAR,
--                 mag_filter = GL.LINEAR,
--                 fbo = true,
--             })
--                     gl.Texture(item)
--             Log.Debug(texInfo.xsize, texInfo.ysize, item)
--             SB.model.textureManager:Blit(item, tex)
            -- local texInfo = gl.TextureInfo(value)
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
    elseif self.mapTextures ~= nil and self.mapTextures[name] ~= nil then
        SB.delayGL(function()
            if value then
                -- Make configurable
                local sizeX, sizeZ
                if name:find("splat_normals") then
                    sizeX, sizeZ = 512, 512
                else
                    sizeX, sizeZ = Game.mapSizeX / 4, Game.mapSizeZ / 4
                end

                local tex = SB.model.textureManager:MakeAndEnableMapShadingTexture(self.mapTextures[name],
                    sizeX, sizeZ)
            else
                SB.model.textureManager:ResetShadingTexture(self.mapTextures[name])
            end
            SB.commandManager:execute(ClearUndoRedoCommand())
        end)
    end
end
