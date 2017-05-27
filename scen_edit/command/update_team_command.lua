UpdateTeamCommand = Command:extends{}
UpdateTeamCommand.className = "UpdateTeamCommand"

function UpdateTeamCommand:init(team)
    self.className = "UpdateTeamCommand"
    self.team = team
end

function UpdateTeamCommand:execute()
    if not self.old then
        self.old = SB.model.teamManager:getTeam(self.team.id)
    end
    SB.model.teamManager:setTeam(self.team.id, self.team)
end

function UpdateTeamCommand:unexecute()
    SB.model.teamManager:setTeam(self.team.id, self.old)
end
