ChangePlayerTeamCommand = Command:extends{}

function ChangePlayerTeamCommand:init(playerID, teamID)
    self.className = "ChangePlayerTeamCommand"
    self.playerID = playerID
    self.teamID = teamID
end

function ChangePlayerTeamCommand:execute()
    local _, _, _, _, prevAllyTeamID = Spring.GetPlayerInfo(self.playerID)
    Spring.AssignPlayerToTeam(self.playerID, self.teamID)

    -- TODO: Should we be invoking the existing SetGlobalLosCommand?
    Spring.SetGlobalLos(prevAllyTeamID, false)
    local _, _, _, _, _, newAllyTeamID = Spring.GetTeamInfo(self.teamID)
    Spring.SetGlobalLos(newAllyTeamID, true)
end
