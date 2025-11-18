--- RmlUi Terrain Settings Editor

RmlUiTerrainSettingsEditor = RmlUiEditorBase:extends{}

function RmlUiTerrainSettingsEditor:init(model)
    self:super("init")
    self.model = model or TerrainSettingsEditorModel()
    self.editorTitle = "Terrain Settings"

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    self:UpdateMapRendering()
    self:AddMapTextureControls()
end

function RmlUiTerrainSettingsEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "asset" then
        self:AddField(AssetField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            rootDir = fieldDef.rootDir,
            width = 200,
        }))
    elseif fieldDef.type == "boolean" then
        self:AddField(BooleanField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            width = 200,
        }))
    elseif fieldDef.type == "group" and fieldDef.fields then
        for _, subFieldDef in ipairs(fieldDef.fields) do
            if subFieldDef.type == "boolean" then
                self:AddField(BooleanField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    tooltip = subFieldDef.tooltip,
                    width = 200,
                }))
            end
        end
    end
end

function RmlUiTerrainSettingsEditor:AddMapTextureControls()
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

function RmlUiTerrainSettingsEditor:UpdateMapRendering()
    local params = self.model:UpdateMapRendering()
    if params then
        for name, value in pairs(params) do
            self:SetFieldValue(name, value)
        end
    end
end

function RmlUiTerrainSettingsEditor:OnStartChange(name)
    self.model:OnStartChange()
end

function RmlUiTerrainSettingsEditor:OnEndChange(name)
    self.model:OnEndChange()
end

function RmlUiTerrainSettingsEditor:OnFieldChange(name, value)
    self.model:OnFieldChange(name, value, self.mapTextures, self.__isLoading)
end
