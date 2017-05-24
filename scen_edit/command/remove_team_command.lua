RemoveTeamCommand = UndoableCommand:extends{}
RemoveTeamCommand.className = "RemoveTeamCommand"

function RemoveTeamCommand:init(teamId)
    self.className = "RemoveTeamCommand"
    self.teamId = teamId
end

function RemoveTeamCommand:execute()
    self.team = SB.model.teamManager:getTeam(self.teamId)
    SB.model.teamManager:removeTeam(self.teamId)
end

function RemoveTeamCommand:unexecute()
    self.teamId = SB.model.teamManager:addTeam(self.team, self.teamId)
end
