RemoveTeamCommand = Command:extends{}
RemoveTeamCommand.className = "RemoveTeamCommand"

function RemoveTeamCommand:init(teamID)
    self.teamID = teamID
end

function RemoveTeamCommand:execute()
    self.team = SB.model.teamManager:getTeam(self.teamID)
    SB.model.teamManager:removeTeam(self.teamID)
end

function RemoveTeamCommand:unexecute()
    self.teamID = SB.model.teamManager:addTeam(self.team, self.teamID)
end
