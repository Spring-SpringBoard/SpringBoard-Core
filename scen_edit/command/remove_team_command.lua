RemoveTeamCommand = Command:extends{}
RemoveTeamCommand.className = "RemoveTeamCommand"

function RemoveTeamCommand:init(teamID)
    self.teamID = teamID
end

function RemoveTeamCommand:execute()
    error("RemoveTeamCommand is native-only; Lua execute should not run")
end

function RemoveTeamCommand:unexecute()
    error("RemoveTeamCommand is native-only; Lua unexecute should not run")
end
