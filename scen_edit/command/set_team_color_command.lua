SetTeamColorCommand = Command:extends{}
SetTeamColorCommand.className = "SetTeamColorCommand"

function SetTeamColorCommand:init(teamId, color)
    self.className = "SetTeamColorCommand"
    self.teamId = teamId
    self.color = color
end

function SetTeamColorCommand:execute()
    self.oldColor = SB.model.teamManager:getTeam(self.teamId).color
    SB.model.teamManager:getTeam(self.teamId).color = self.color
end

function SetTeamColorCommand:unexecute()
    SB.model.teamManager:getTeam(self.teamId).color = self.oldColor
end
