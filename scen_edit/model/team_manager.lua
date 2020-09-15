TeamManager = Observable:extends{}

function TeamManager:init()
    self:super('init')
    self.teamIDCount = 0
    self.teams = {}

    self.__isWidget = Script.GetName() == "LuaUI"

    -- part of the hack to not update from widget during load
    self.__loaded_from_file = false
end

function TeamManager:addTeam(team, teamID)
    if teamID == nil then
        teamID = self.teamIDCount + 1
    end
    team.id = teamID
    if teamID > self.teamIDCount then
        self.teamIDCount = teamID
    end

    self.teams[teamID] = team
    self:callListeners("onTeamAdded", teamID)

    self:setTeam(teamID, team)

    return teamID
end

function TeamManager:removeTeam(teamID)
    assert(self.teams[teamID] ~= nil)
    self.teams[teamID] = nil
    self:callListeners("onTeamRemoved", teamID)
end

function TeamManager:setTeam(teamID, team)
    assert(self.teams[teamID] ~= nil)

    self.teams[teamID] = team
    if team.color then
        Spring.SetTeamColor(teamID, team.color.r, team.color.g, team.color.b)
    end
    if Script.GetSynced() then
        self:setTeamResources(teamID, team.metal, team.metalMax, team.energy, team.energyMax)
    end
    self:callListeners("onTeamChange", teamID, team)
end

function TeamManager:getTeam(teamID)
    return self.teams[teamID]
end

function TeamManager:getAllTeams()
    return self.teams
end

function TeamManager:setTeamResources(teamID, metal, metalMax, energy, energyMax)
    if metal then
        Spring.SetTeamResource(teamID, "m", metal)
    end
    if metalMax then
        Spring.SetTeamResource(teamID, "ms", metalMax)
    end
    if energy then
        Spring.SetTeamResource(teamID, "e", energy)
    end
    if energyMax then
        Spring.SetTeamResource(teamID, "es", energyMax)
    end
end

function TeamManager:serialize()
    local retVal = {}
    local teams = Table.DeepCopy(self.teams)
    for team1ID, team in pairs(teams) do
        team.allies = {}
        for team2ID, _ in pairs(teams) do
            if Spring.AreTeamsAllied(team1ID, team2ID) then
                table.insert(team.allies, team2ID)
            end
        end
        table.insert(retVal, {
            team = team,
            id = team1ID,
        })
    end
    return retVal
end

function TeamManager:load(data)
    self.__loaded_from_file = true
    self:clear()
    for _, kv in pairs(data) do
        local team = kv.team

        if Spring.SetAlly ~= nil then
            -- TODO: only change those alliances that are needed
            for _, team2 in pairs(self.teams) do
                if team.id ~= team2.id then
                    Spring.SetAlly(team.allyTeam, team2.allyTeam, false)
                end
            end
            for _, allyTeam2 in pairs(team.allies) do
                Spring.SetAlly(team.allyTeam, allyTeam2, true)
            end
        end
        team.allies = nil

        self:addTeam(team, team.id)
    end
end

function TeamManager:clear()
    for teamID, _ in pairs(self.teams) do
        self:removeTeam(teamID)
    end
    self.teamIDCount = 0
end

local function _GenerateTeams()
    local teams = {}

    local gaiaTeamID = Spring.GetGaiaTeamID()
    for _, teamID in pairs(Spring.GetTeamList()) do
        local team = { id = teamID }
        table.insert(teams, team)

        -- Temporary name. Later we use the name generated from unsynced.
        -- See team_sync.lua
        team.name = tostring(teamID)

        local aiID = Spring.GetAIInfo(teamID)
        if aiID ~= nil then
            team.ai = true
        end
        local _, _, _, _, side, allyTeam = Spring.GetTeamInfo(teamID)
        team.side = side
        team.allyTeam = allyTeam

        team.gaia = gaiaTeamID == teamID
        if team.gaia then
            team.ai = true
        end

        local metal, metalMax = Spring.GetTeamResources(teamID, "metal")
        team.metal = metal
        team.metalMax = metalMax

        local energy, energyMax = Spring.GetTeamResources(teamID, "energy")
        team.energy = energy
        team.energyMax = energyMax
    end
    return teams
end

function TeamManager:populate()
    if self.__isWidget then
        return
    end

    local teams = _GenerateTeams()
    self.teams = {}
    for _, team in pairs(teams) do
        self:addTeam(team, team.id)
    end
end

------------------------------------------------
-- Listener definition
------------------------------------------------
TeamManagerListener = LCS.class.abstract{}

function TeamManagerListener:onTeamAdded(teamID)
end

function TeamManagerListener:onTeamRemoved(teamID)
end

function TeamManagerListener:onTeamChange(teamID, team)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
