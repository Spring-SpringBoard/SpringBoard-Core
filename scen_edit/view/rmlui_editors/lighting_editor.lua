--- RmlUi Lighting Editor

RmlUiLightingEditor = RmlUiEditorBase:extends{}

function RmlUiLightingEditor:init(model)
    self:super("init")
    self.model = model or LightingEditorModel()
    self.editorTitle = "Lighting Editor"

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    self:SetFieldValue("shadowMode", self.model:GetInitialShadowMode())
    self:UpdateLighting()
    SB.commandManager:addListener(self)
end

function RmlUiLightingEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "choice" then
        self:AddField(ChoiceField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            items = fieldDef.items,
            width = 200,
        }))
    elseif fieldDef.type == "numeric" then
        self:AddField(NumericField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            value = fieldDef.value,
            min = fieldDef.min,
            max = fieldDef.max,
            width = 200,
        }))
    elseif fieldDef.type == "group" and fieldDef.fields then
        for _, subFieldDef in ipairs(fieldDef.fields) do
            if subFieldDef.type == "numeric" then
                self:AddField(NumericField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    tooltip = subFieldDef.tooltip,
                    value = subFieldDef.value,
                    step = subFieldDef.step,
                    width = 200,
                }))
            elseif subFieldDef.type == "color" then
                self:AddField(ColorField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    tooltip = subFieldDef.tooltip,
                    width = 200,
                    format = subFieldDef.format,
                }))
            end
        end
    end
end

function RmlUiLightingEditor:UpdateLighting()
    self.updating = true
    local params = self.model:UpdateLighting()
    for name, value in pairs(params) do
        self:SetFieldValue(name, value)
    end
    self.updating = false
end

function RmlUiLightingEditor:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateLighting()
    end
end

function RmlUiLightingEditor:OnStartChange(name)
    self.model:OnStartChange()
end

function RmlUiLightingEditor:OnEndChange(name)
    self.model:OnEndChange()
end

function RmlUiLightingEditor:OnFieldChange(name, value)
    if self.updating then
        return
    end
    self.model:OnFieldChange(name, value, self.fields)
end
