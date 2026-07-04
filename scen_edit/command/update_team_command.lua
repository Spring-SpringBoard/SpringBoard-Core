UpdateTeamCommand = NativeCommand:extends{}
UpdateTeamCommand.className = "UpdateTeamCommand"

function UpdateTeamCommand:init(team, onlyIfNoTeamColor)
    self.team = team
    self.onlyIfNoTeamColor = onlyIfNoTeamColor
end
