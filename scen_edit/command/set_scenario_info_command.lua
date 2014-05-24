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
    self.oldName = SCEN_EDIT.model.scenarioInfo.name
    self.oldDescription = SCEN_EDIT.model.scenarioInfo.description
    self.oldVersion = SCEN_EDIT.model.scenarioInfo.version
    self.oldAuthor = SCEN_EDIT.model.scenarioInfo.author

	SCEN_EDIT.model.scenarioInfo:Set(self.name, self.description, self.version, self.author)
end

function SetScenarioInfoCommand:unexecute()
    SCEN_EDIT.model.scenarioInfo:Set(self.oldName, self.oldDescription, self.oldVersion, self.oldAuthor)
end
