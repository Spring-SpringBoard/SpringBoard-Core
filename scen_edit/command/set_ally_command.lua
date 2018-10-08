SetAllyCommand = Command:extends{}
SetAllyCommand.className = "SetAllyCommand"

function SetAllyCommand:init(firstAllyTeamID, secondAllyTeamID, ally)
    self.firstAllyTeamID = firstAllyTeamID
    self.secondAllyTeamID = secondAllyTeamID
    self.ally = ally
end

function SetAllyCommand:execute()
    Spring.SetAlly(self.firstAllyTeamID, self.secondAllyTeamID, self.ally)
end
