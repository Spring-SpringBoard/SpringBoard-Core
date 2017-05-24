SetScenarioInfoCommand = UndoableCommand:extends{}
SetScenarioInfoCommand.className = "SetScenarioInfoCommand"

function SetScenarioInfoCommand:init(name, description, version, author)
    self.className = "SetScenarioInfoCommand"
    self.name = name
    self.description = description
    self.version = version
    self.author = author
end

function SetScenarioInfoCommand:execute()
    self.oldName = SB.model.scenarioInfo.name
    self.oldDescription = SB.model.scenarioInfo.description
    self.oldVersion = SB.model.scenarioInfo.version
    self.oldAuthor = SB.model.scenarioInfo.author

	SB.model.scenarioInfo:Set(self.name, self.description, self.version, self.author)
end

function SetScenarioInfoCommand:unexecute()
    SB.model.scenarioInfo:Set(self.oldName, self.oldDescription, self.oldVersion, self.oldAuthor)
end
