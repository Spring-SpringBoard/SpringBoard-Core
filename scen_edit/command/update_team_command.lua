UpdateTeamCommand = Command:extends{}
UpdateTeamCommand.className = "UpdateTeamCommand"

function UpdateTeamCommand:init(team)
    self.className = "UpdateTeamCommand"
    self.team = team
end

function UpdateTeamCommand:execute()
    self.old = SB.model.teamManager:getTeam(self.team.id)
    SB.model.teamManager:setTeam(self.team.id, self.team)
    Spring.SetTeamColor(self.team.id, self.team.color.r, self.team.color.g, self.team.color.b)
	SB.model.teamManager:setTeamResources(self.team.id, self.team.metal, self.team.metalMax, self.team.energy, self.team.energyMax)
end

function UpdateTeamCommand:unexecute()
    SB.model.teamManager:setTeam(self.team.id, self.old)
    Spring.SetTeamColor(self.old.id, self.old.color.r, self.old.color.g, self.old.color.b)
	SB.model.teamManager:setTeamResources(self.team.id, self.old.metal, self.old.metalMax, self.old.energy, self.old.energyMax)
end
