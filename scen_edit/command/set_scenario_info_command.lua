SetScenarioInfoCommand = Command:extends{}
SetScenarioInfoCommand.className = "SetScenarioInfoCommand"

function SetScenarioInfoCommand:init(data)
    self.data = data
end

function SetScenarioInfoCommand:execute()
    if not self.oldData then
        self.oldData = SB.model.scenarioInfo:serialize()
    end
    SB.model.scenarioInfo:Set(self.data)
end

function SetScenarioInfoCommand:unexecute()
    SB.model.scenarioInfo:Set(self.oldData)
end
