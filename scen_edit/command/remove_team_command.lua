RemoveTeamCommand = UndoableCommand:extends{}
RemoveTeamCommand.className = "RemoveTeamCommand"

function RemoveTeamCommand:init(teamId)
    self.className = "RemoveTeamCommand"
    self.teamId = teamId
end

function RemoveTeamCommand:execute()
    self.team = SCEN_EDIT.model.teamManager:getTeam(self.teamId)
    SCEN_EDIT.model.teamManager:removeTeam(self.teamId)
end

function RemoveTeamCommand:unexecute()
    self.teamId = SCEN_EDIT.model.teamManager:addTeam(self.team, self.teamId)
end
