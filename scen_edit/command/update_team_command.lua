UpdateTeamCommand = UndoableCommand:extends{}
UpdateTeamCommand.className = "UpdateTeamCommand"

function UpdateTeamCommand:init(team)
    self.className = "UpdateTeamCommand"
    self.team = team
end

function UpdateTeamCommand:execute()
    self.old = SCEN_EDIT.model.teamManager:getTeam(self.team.id)
    SCEN_EDIT.model.teamManager:setTeam(self.team.id, self.team)
    Spring.SetTeamColor(self.team.id, self.team.color.r, self.team.color.g, self.team.color.b)
end

function UpdateTeamCommand:unexecute()
    SCEN_EDIT.model.teamManager:setTeam(self.team.id, self.old)
    Spring.SetTeamColor(self.old.id, self.old.color.r, self.old.color.g, self.old.color.b)
end
