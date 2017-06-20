ChangePlayerTeamCommand = Command:extends{}

function ChangePlayerTeamCommand:init(playerID, teamID)
    self.className = "ChangePlayerTeamCommand"
    self.playerID = playerID
    self.teamID = teamID
end

function ChangePlayerTeamCommand:execute()
    Spring.AssignPlayerToTeam(self.playerID, self.teamID)
end
