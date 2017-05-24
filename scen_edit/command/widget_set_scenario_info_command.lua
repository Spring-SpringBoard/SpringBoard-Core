WidgetSetScenarioInfoCommand = UndoableCommand:extends{}
WidgetSetScenarioInfoCommand.className = "WidgetSetScenarioInfoCommand"

function WidgetSetScenarioInfoCommand:init(name, description, version, author)
    self.className = "WidgetSetScenarioInfoCommand"
    self.name = name
    self.description = description
    self.version = version
    self.author = author
end

function WidgetSetScenarioInfoCommand:execute()
	SB.model.scenarioInfo:Set(self.name, self.description, self.version, self.author)
end
