SetAllyCommand = AbstractCommand:extends{}
SetAllyCommand.className = "SetAllyCommand"

function SetAllyCommand:init(firstAllyTeamId, secondAllyTeamId, ally)
    self.className = "SetAllyCommand"
    self.firstAllyTeamId = firstAllyTeamId
    self.secondAllyTeamId = secondAllyTeamId
    self.ally = ally
end

function SetAllyCommand:execute()
    Spring.SetAlly(self.firstAllyTeamId, self.secondAllyTeamId, self.ally)    
end
