UpdateTeamCommand = Command:extends{}
UpdateTeamCommand.className = "UpdateTeamCommand"

function UpdateTeamCommand:init(team, onlyIfNoTeamColor)
    self.team = team
    self.onlyIfNoTeamColor = onlyIfNoTeamColor
end

function UpdateTeamCommand:execute()
    error("UpdateTeamCommand is native-only; Lua execute should not run")
end

function UpdateTeamCommand:unexecute()
    error("UpdateTeamCommand is native-only; Lua unexecute should not run")
end
