ChangePlayerTeamCommand = NativeCommand:extends{}
ChangePlayerTeamCommand.className = "ChangePlayerTeamCommand"

function ChangePlayerTeamCommand:init(playerID, teamID)
    self.playerID = playerID
    self.teamID = teamID
end
