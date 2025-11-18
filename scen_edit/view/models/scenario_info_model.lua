ScenarioInfoModel = LCS.class{}

function ScenarioInfoModel:init()
end

function ScenarioInfoModel:GetFieldDefinitions()
    return {
        {type = "string", name = "name", title = "Name:", width = 200, value = SB.model.scenarioInfo.name},
        {type = "string", name = "description", title = "Description:", width = 200, value = SB.model.scenarioInfo.description},
        {type = "string", name = "version", title = "Version:", width = 200, value = tostring(SB.model.scenarioInfo.version)},
        {type = "string", name = "author", title = "Author:", width = 200, value = SB.model.scenarioInfo.author},
    }
end

function ScenarioInfoModel:AddListener(listener)
    SB.model.scenarioInfo:addListener(listener)
end

function ScenarioInfoModel:OnStartChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function ScenarioInfoModel:OnEndChange()
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function ScenarioInfoModel:OnFieldChange(fields)
    local cmd = SetScenarioInfoCommand({
        name = fields['name'].value,
        description = fields['description'].value,
        version = fields['version'].value,
        author = fields['author'].value,
    })
    SB.commandManager:execute(cmd)
end
