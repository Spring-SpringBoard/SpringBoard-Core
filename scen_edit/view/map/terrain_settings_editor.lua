SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

TerrainSettingsEditor = Editor:extends{}
TerrainSettingsEditor:Register({
    name = "terrainSettings",
    tab = "Map",
    caption = "Settings",
    tooltip = "Edit map settings",
    image = Path.Join(SB.DIRS.IMG, 'globe.png'),
    order = 5,
})

function TerrainSettingsEditor:init(model)
    self:super("init")
    self.model = model or TerrainSettingsEditorModel()

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    self:UpdateMapRendering()
    self:AddMapTextureControls()

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

function TerrainSettingsEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "asset" then
        self:AddField(AssetField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            rootDir = fieldDef.rootDir,
            width = fieldDef.width,
        }))
    elseif fieldDef.type == "boolean" then
        self:AddField(BooleanField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            width = fieldDef.width,
        }))
    elseif fieldDef.type == "separator" then
        self:AddControl(fieldDef.name, {
            Label:New {
                caption = fieldDef.caption,
            },
            Line:New {
                x = 150,
            }
        })
    elseif fieldDef.type == "group" then
        local groupFields = {}
        for _, subFieldDef in ipairs(fieldDef.fields) do
            if subFieldDef.type == "boolean" then
                table.insert(groupFields, BooleanField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    tooltip = subFieldDef.tooltip,
                    width = subFieldDef.width,
                }))
            end
        end
        self:AddField(GroupField(groupFields))
    end
end

function TerrainSettingsEditor:AddMapTextureControls()
    self.mapTextures = {}
    local textures = self.model:GetMapTextures()
    for _, tex in ipairs(textures) do
        local fname = "tex_" .. tostring(tex.name)
        self.mapTextures[fname] = tex.name
        self:AddField(BooleanField({
            name = fname,
            value = tex.exists,
            title = String.Capitalize(tex.name),
            tooltip = "Toggle texture enable: " .. tostring(tex.engineName),
            width = 200,
        }))
    end
end

function TerrainSettingsEditor:UpdateMapRendering()
    local params = self.model:UpdateMapRendering()
    if params then
        for name, value in pairs(params) do
            self:Set(name, value)
        end
    end
end

function TerrainSettingsEditor:OnStartChange(name)
    self.model:OnStartChange()
end

function TerrainSettingsEditor:OnEndChange(name)
    self.model:OnEndChange()
end

function TerrainSettingsEditor:OnFieldChange(name, value)
    local result = self.model:OnFieldChange(name, value, self.mapTextures, self.__isLoading)
    if result and result.createDialog then
        SB.Include(Path.Join(SB.DIRS.SRC, 'view/new_texture_dialog.lua'))
        NewEngineTextureDialog = NewTextureDialog:extends{}

        function NewEngineTextureDialog:ConfirmDialog()
            SB.delayGL(function()
                local opts = {
                    name = self.engineName,
                    sizeX = self.fields["sizeX"].value,
                    sizeY = self.fields["sizeY"].value
                }
                if self.fields.source.value == 'New' then
                    opts.color = self.fields["color"].value
                else
                    opts.texture = self.fields["texture"].value
                end
                local tex = SB.model.textureManager:MakeAndEnableMapShadingTexture(opts)
                SB.commandManager:execute(ClearUndoRedoCommand())
            end)
            return true
        end

        NewEngineTextureDialog(result)
    end
end
