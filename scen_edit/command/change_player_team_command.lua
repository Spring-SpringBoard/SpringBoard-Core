ChangePlayerTeamCommand = AbstractCommand:extends{}

function ChangePlayerTeamCommand:init(playerId, teamId)
    self.className = "ChangePlayerTeamCommand"
    self.playerId = playerId
    self.teamId = teamId
end

function ChangePlayerTeamCommand:execute()
    Spring.AssignPlayerToTeam(self.playerId, self.teamId)
end
