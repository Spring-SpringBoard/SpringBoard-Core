SetAllyCommand = NativeCommand:extends{}
SetAllyCommand.className = "SetAllyCommand"

function SetAllyCommand:init(firstAllyTeamID, secondAllyTeamID, ally)
    self.firstAllyTeamID = firstAllyTeamID
    self.secondAllyTeamID = secondAllyTeamID
    self.ally = ally
end
