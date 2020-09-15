UpdateTeamCommand = Command:extends{}
UpdateTeamCommand.className = "UpdateTeamCommand"

function UpdateTeamCommand:init(team, onlyIfNoTeamColor)
    self.team = team
    self.onlyIfNoTeamColor = onlyIfNoTeamColor
end

function UpdateTeamCommand:execute()
    if not self.old then
        self.old = SB.model.teamManager:getTeam(self.team.id)

        if self.onlyIfNoTeamColor then
            if self.old.color then
                return
            end
        end
    end
    SB.model.teamManager:setTeam(self.team.id, self.team)
end

function UpdateTeamCommand:unexecute()
    SB.model.teamManager:setTeam(self.team.id, self.old)
end
