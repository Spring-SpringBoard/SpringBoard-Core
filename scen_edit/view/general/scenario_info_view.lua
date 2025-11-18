SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

ScenarioInfoView = Editor:extends{}
ScenarioInfoView:Register({
    name = "scenarioInfoView",
    tab = "Misc",
    caption = "Info",
    tooltip = "Edit project info",
    image = Path.Join(SB.DIRS.IMG, 'info.png'),
    order = 0,
})

function ScenarioInfoView:init(model)
    self:super("init")
    self.model = model or ScenarioInfoModel()

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddField(StringField({
            name = fieldDef.name,
            title = fieldDef.title,
            width = fieldDef.width,
            value = fieldDef.value,
        }))
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

    self.model:AddListener(ScenarioInfoListenerWidget(self))
    self:Finalize(children)
end

function ScenarioInfoView:OnStartChange(name)
    self.model:OnStartChange()
end

function ScenarioInfoView:OnEndChange(name)
    self.model:OnEndChange()
end

function ScenarioInfoView:OnFieldChange(name, value)
    if self.updatingInfo then
        return
    end
    self.model:OnFieldChange(self.fields)
end

function ScenarioInfoView:UpdateInfo(update)
    if self._startedChanging then
        return
    end

    self.updatingInfo = true
    for k, v in pairs(update) do
        self:Set(k, v)
    end
    self.updatingInfo = false
end

ScenarioInfoListenerWidget = ScenarioInfoListener:extends{}
function ScenarioInfoListenerWidget:init(scenarioInfoView)
    self.scenarioInfoView = scenarioInfoView
end

function ScenarioInfoListenerWidget:onSet(data)
    self.scenarioInfoView:UpdateInfo(data)
end
