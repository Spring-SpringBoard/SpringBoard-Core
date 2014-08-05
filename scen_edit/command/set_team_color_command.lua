SetTeamColorCommand = UndoableCommand:extends{}
SetTeamColorCommand.className = "SetTeamColorCommand"

function SetTeamColorCommand:init(teamId, color)
    self.className = "SetTeamColorCommand"
    self.teamId = teamId
    self.color = color
end

function SetTeamColorCommand:execute()
    self.oldColor = SCEN_EDIT.model.teamManager:getTeam(self.teamId).color
    SCEN_EDIT.model.teamManager:getTeam(self.teamId).color = self.color
end

function SetTeamColorCommand:unexecute()
    SCEN_EDIT.model.teamManager:getTeam(self.teamId).color = self.oldColor
end
