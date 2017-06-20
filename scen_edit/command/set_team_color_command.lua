SetTeamColorCommand = Command:extends{}
SetTeamColorCommand.className = "SetTeamColorCommand"

function SetTeamColorCommand:init(teamID, color)
    self.className = "SetTeamColorCommand"
    self.teamID = teamID
    self.color = color
end

function SetTeamColorCommand:execute()
    self.oldColor = SB.model.teamManager:getTeam(self.teamID).color
    SB.model.teamManager:getTeam(self.teamID).color = self.color
end

function SetTeamColorCommand:unexecute()
    SB.model.teamManager:getTeam(self.teamID).color = self.oldColor
end
