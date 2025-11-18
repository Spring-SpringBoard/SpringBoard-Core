--- RmlUi Water Editor

RmlUiWaterEditor = RmlUiEditorBase:extends{}

function RmlUiWaterEditor:init(model)
    self:super("init")
    self.model = model or WaterEditorModel()
    self.editorTitle = "Water Editor"

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    self:UpdateWaterRendering()
    SB.commandManager:addListener(self)
end

function RmlUiWaterEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "asset" then
        self:AddField(AssetField({
            name = fieldDef.name,
            title = fieldDef.title,
            width = fieldDef.width,
            tooltip = fieldDef.tooltip,
            caption = fieldDef.caption,
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
                    value = subFieldDef.value,
                }))
            elseif subFieldDef.type == "boolean" then
                self:AddField(BooleanField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = 200,
                    tooltip = subFieldDef.tooltip,
                }))
            elseif subFieldDef.type == "color" then
                self:AddField(ColorField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = 200,
                    tooltip = subFieldDef.tooltip,
                    format = subFieldDef.format,
                }))
            elseif subFieldDef.type == "asset" then
                self:AddField(AssetField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = 200,
                    caption = subFieldDef.caption,
                }))
            end
        end
    end
end

function RmlUiWaterEditor:UpdateWaterRendering()
    self.updating = true
    local params = self.model:UpdateWaterRendering()
    if params then
        for name, value in pairs(params) do
            self:SetFieldValue(name, value)
        end
    end
    self.updating = false
end

function RmlUiWaterEditor:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateWaterRendering()
    end
end

function RmlUiWaterEditor:OnStartChange(name)
    self.model:OnStartChange()
end

function RmlUiWaterEditor:OnEndChange(name)
    self.model:OnEndChange()
end

function RmlUiWaterEditor:OnFieldChange(name, value)
    if self.updating then
        return
    end
    self.model:OnFieldChange(name, value)
end
