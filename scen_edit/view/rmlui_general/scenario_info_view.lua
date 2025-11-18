--- RmlUi Scenario Info View

RmlUiScenarioInfoView = RmlUiEditorBase:extends{}

function RmlUiScenarioInfoView:init(model)
    self:super("init")
    self.model = model or ScenarioInfoModel()
    self.editorTitle = "Scenario Info"

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddField(StringField({
            name = fieldDef.name,
            title = fieldDef.title,
            width = fieldDef.width,
            value = fieldDef.value,
        }))
    end

    self.model:AddListener(ScenarioInfoListenerWidget(self))
end

function RmlUiScenarioInfoView:OnStartChange(name)
    self.model:OnStartChange()
end

function RmlUiScenarioInfoView:OnEndChange(name)
    self.model:OnEndChange()
end

function RmlUiScenarioInfoView:OnFieldChange(name, value)
    if self.updatingInfo then
        return
    end
    self.model:OnFieldChange(self.fields)
end

function RmlUiScenarioInfoView:UpdateInfo(update)
    if self._startedChanging then
        return
    end

    self.updatingInfo = true
    for k, v in pairs(update) do
        self:SetFieldValue(k, v)
    end
    self.updatingInfo = false
end
