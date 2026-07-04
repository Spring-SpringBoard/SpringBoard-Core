AddTeamCommand = NativeCommand:extends{}
AddTeamCommand.className = "AddTeamCommand"

function AddTeamCommand:init(name, color, allyTeam, side)
    self.name = name
    self.color = color
    self.allyTeam = allyTeam
    self.side = side
end
