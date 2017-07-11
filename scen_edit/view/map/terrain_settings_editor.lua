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

local WRITE_DATA_DIR = nil
local function GetWriteDataDir()
	if WRITE_DATA_DIR then
		return WRITE_DATA_DIR
	end

	local dataDirStr = "write data directory: "
	lines = explode("\n", VFS.LoadFile("infolog.txt", nil, VFS.RAW))
	dataDir = ""
	for i, line in pairs(lines) do
	    if line:find(dataDirStr) then
	        dataDir = line:sub(line:find(dataDirStr) + #dataDirStr)
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

    self.btnCompile = Button:New ({
        caption = "Compile",
        height = 30,
        width = 150,
        OnClick = {
            function()
                local folderPath = Path.Join(GetWriteDataDir(), SB_PROJECTS_DIR, "comp1")
                WG.Connector.Send({
                    name = "CompileMap",
                    command = {
                        heightPath = Path.Join(folderPath, "heightmap.png"),
                        diffusePath = Path.Join(folderPath, "texture.png"),
                        grass = Path.Join(folderPath, "grass.png"),
                        outputPath = Path.Join(folderPath, "MyName"),
                    }
                })
            end
        }
    })
    self.progressBar = Progressbar:New ({
        x = 160,
        height = 30,
        width = 200,
        value = 0,
    })
    self:AddField(Field({
        name = "btnCompile",
        height = 30,
        components = {
            self.btnCompile,
            self.progressBar,
        }
    }))

    WG.Connector.Register("StartCompiling", function()
        self.progressBar:SetCaption("Starting...")
    end)

    WG.Connector.Register("FinishCompiling", function()
        self.progressBar:SetCaption("Finished")
    end)

    WG.Connector.Register("UpdateCompiling", function(command)
        local est, total = command.est, command.total
        local value = est * 100 / total
        value = math.max(value, 0)
        value = math.min(value, 100)
        self.progressBar:SetValue(value)
        if self.progressBar.caption ~= "Compiling" then
            self.progressBar:SetCaption("Compiling")
        end
    end)

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
