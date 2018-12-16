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

local WRITE_DATA_DIR = nil
local function GetWriteDataDir()
    if WRITE_DATA_DIR then
        return WRITE_DATA_DIR
    end

    local dataDirStr = "write data directory: "
    local lines = String.Explode("\n", VFS.LoadFile("infolog.txt", nil, VFS.RAW))
    local dataDir = ""
    for i, line in pairs(lines) do
        if line:find(dataDirStr) then
            dataDir = line:sub(line:find(dataDirStr) + #dataDirStr)
            dataDir = dataDir:gsub("\r", "")
            break
        end
    end
    WRITE_DATA_DIR = dataDir
    return WRITE_DATA_DIR
end

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

    if WG.Connector then
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
            width = 100,
            OnClick = {
                function()
                    self.progressBar.tooltip = ""
                    self.progressBar:SetCaption("")

                    local folderPath = self.fields["compileFolder"].value
                    if folderPath == nil then
                        Spring.Echo("Choose a folder with textures first.")
                        return
                    end

                    local heightPath = Path.Join(folderPath, "heightmap.png")
                    local diffusePath = Path.Join(folderPath, "diffuse.png")
                    local grass = Path.Join(folderPath, "grass.png")
                    local outputPath = Path.Join(folderPath, "MyName")

                    if not VFS.FileExists(heightPath, VFS.RAW) then
                        Spring.Echo("Heightmap texture missing from: " .. tostring(heightPath))
                        return
                    end

                    if not VFS.FileExists(diffusePath, VFS.RAW) then
                        Spring.Echo("Diffuse texture missing from: " .. tostring(diffusePath))
                        return
                    end

                    folderPath = Path.Join(GetWriteDataDir(), folderPath)

                    heightPath = Path.Join(folderPath, "heightmap.png")
                    diffusePath = Path.Join(folderPath, "diffuse.png")
                    grass = Path.Join(folderPath, "grass.png")
                    outputPath = Path.Join(folderPath, "MyName")
                    self.compileFolderPath = folderPath

                    WG.Connector.Send("CompileMap", {
                        heightPath = heightPath,
                        diffusePath = diffusePath,
                        grass = grass,
                        outputPath = outputPath,
                    })
                end
            }
        })
        self.progressBar = Progressbar:New ({
            x = 105,
            height = 30,
            width = 120,
            value = 0,
        })
        self:AddField(GroupField({
            AssetField({
                name = "compileFolder",
                title = "Folder:",
                tooltip = "Select the compile folder with textures",
                value = SB_PROJECTS_DIR,
            }),
            Field({
                name = "btnCompile",
                height = 30,
                width = 220,
                components = {
                    self.btnCompile,
                    self.progressBar,
                }
            }),
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
    end

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
    end
end
