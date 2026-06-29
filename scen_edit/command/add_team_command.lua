AddTeamCommand = Command:extends{}
AddTeamCommand.className = "AddTeamCommand"

function AddTeamCommand:init(name, color, allyTeam, side)
    self.name = name
    self.color = color
    self.allyTeam = allyTeam
    self.side = side
end

function AddTeamCommand:execute()
    error("AddTeamCommand is native-only; Lua execute should not run")
end

function AddTeamCommand:unexecute()
    error("AddTeamCommand is native-only; Lua unexecute should not run")
end
