WidgetUpdateTeamCommand = AbstractCommand:extends{}

function WidgetUpdateTeamCommand:init(teamId, team)
    self.className = "WidgetUpdateTeamCommand"
    self.teamId = teamId
    self.team = team
end

function WidgetUpdateTeamCommand:execute()
    SB.model.teamManager:setTeam(self.teamId, self.team)
end
