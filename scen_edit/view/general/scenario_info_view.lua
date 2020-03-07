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

function ScenarioInfoView:init()
    self:super("init")

    self:AddField(
        StringField({
            name = "name",
            title = "Name:",
            width = 200,
            value = SB.model.scenarioInfo.name,
        })
    )

    self:AddField(
        StringField({
            name = "description",
            title = "Description:",
            width = 200,
            value = SB.model.scenarioInfo.description,
        })
    )

    self:AddField(
        StringField({
            name = "version",
            title = "Version:",
            width = 200,
            value = tostring(SB.model.scenarioInfo.version),
        })
    )

    self:AddField(
        StringField({
            name = "author",
            title = "Author:",
            width = 200,
            value = SB.model.scenarioInfo.author,
        })
    )

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

    SB.model.scenarioInfo:addListener(ScenarioInfoListenerWidget(self))

    self:Finalize(children)
end

function ScenarioInfoView:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function ScenarioInfoView:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function ScenarioInfoView:OnFieldChange(name, value)
    if self.updatingInfo then
        return
    end

    local cmd = SetScenarioInfoCommand({
        name = self.fields['name'].value,
        description = self.fields['description'].value,
        version = self.fields['version'].value,
        author = self.fields['author'].value,
    })
    SB.commandManager:execute(cmd)
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
