--- RmlUi Sky Editor

RmlUiSkyEditor = RmlUiEditorBase:extends{}

function RmlUiSkyEditor:init(model)
    self:super("init")
    self.model = model or SkyEditorModel()
    self.editorTitle = "Sky Editor"

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    self:UpdateAtmosphere()
    SB.commandManager:addListener(self)
end

function RmlUiSkyEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "asset" then
        self:AddField(AssetField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            rootDir = fieldDef.rootDir,
            width = 200,
        }))
    elseif fieldDef.type == "group" and fieldDef.fields then
        for _, subFieldDef in ipairs(fieldDef.fields) do
            if subFieldDef.type == "numeric" then
                self:AddField(NumericField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = 200,
                    tooltip = subFieldDef.tooltip,
                    min = subFieldDef.min,
                    max = subFieldDef.max,
                }))
            elseif subFieldDef.type == "color" then
                self:AddField(ColorField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = 200,
                    tooltip = subFieldDef.tooltip,
                    format = subFieldDef.format,
                }))
            end
        end
    end
end

function RmlUiSkyEditor:UpdateAtmosphere()
    self.updating = true
    local params = self.model:UpdateAtmosphere()
    for name, value in pairs(params) do
        self:SetFieldValue(name, value)
    end
    self.updating = false
end

function RmlUiSkyEditor:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateAtmosphere()
    end
end

function RmlUiSkyEditor:OnStartChange(name)
    self.model:OnStartChange()
end

function RmlUiSkyEditor:OnEndChange(name)
    self.model:OnEndChange()
end

function RmlUiSkyEditor:OnFieldChange(name, value)
    if self.updating then
        return
    end
    self.model:OnFieldChange(name, value)
end
