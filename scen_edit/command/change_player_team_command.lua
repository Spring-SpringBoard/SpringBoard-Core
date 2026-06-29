ChangePlayerTeamCommand = Command:extends{}
ChangePlayerTeamCommand.className = "ChangePlayerTeamCommand"

function ChangePlayerTeamCommand:init(playerID, teamID)
    self.playerID = playerID
    self.teamID = teamID
end

function ChangePlayerTeamCommand:execute()
    error("ChangePlayerTeamCommand is native-only; Lua execute should not run")
end
