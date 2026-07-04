RemoveTeamCommand = NativeCommand:extends{}
RemoveTeamCommand.className = "RemoveTeamCommand"

function RemoveTeamCommand:init(teamID)
    self.teamID = teamID
end
