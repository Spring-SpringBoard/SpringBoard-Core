AddTeamCommand = Command:extends{}
AddTeamCommand.className = "AddTeamCommand"

function AddTeamCommand:init(name, color, allyTeam, side)
    self.name = name
    self.color = color
    self.allyTeam = allyTeam
    self.side = side
end

function AddTeamCommand:execute()
    local team = {
        name = self.name,
        color = self.color,
        allyTeam = self.allyTeam,
        side = self.side,
    }
    self.newTeamID = SB.model.teamManager:addTeam(team)
end

function AddTeamCommand:unexecute()
    SB.model.teamManager:removeTeam(self.newTeamID)
end
