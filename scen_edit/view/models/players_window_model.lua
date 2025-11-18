PlayersWindowModel = LCS.class{}

function PlayersWindowModel:init()
end

function PlayersWindowModel:GetAllTeams()
    return SB.model.teamManager:getAllTeams()
end

function PlayersWindowModel:AddTeam()
    local name = "New team: " .. tostring(#SB.model.teamManager:getAllTeams())
    local color = {r=math.random(), g=math.random(), b=math.random(), a=1}
    local allyTeam = 1
    local side = Spring.GetSideData(1)
    local cmd = AddTeamCommand(name, color, allyTeam, side)
    SB.commandManager:execute(cmd)
end

function PlayersWindowModel:RemoveTeam(teamID)
    local cmd = RemoveTeamCommand(teamID)
    SB.commandManager:execute(cmd)
end

function PlayersWindowModel:AddTeamListener(listener)
    SB.model.teamManager:addListener(listener)
end
