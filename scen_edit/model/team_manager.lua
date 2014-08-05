TeamManager = Observable:extends{}

function TeamManager:init()
    self:super('init')
    self.teamIdCount = 0
    self.teams = {}
end

function TeamManager:addTeam(team, teamId)
    if teamId == nil then
        teamId = self.teamIdCount + 1
    end
    self.teamIdCount = teamId
    self.teams[teamId] = team
    self:callListeners("onTeamAdded", teamId)
    return teamId
end

function TeamManager:removeTeam(teamId)
    assert(self.teams[teamId])
    if self.teams[teamId] ~= nil then
        self.teams[teamId] = nil
        self:callListeners("onTeamRemoved", teamId)
    end
end

function TeamManager:setTeam(teamId, value)
    assert(self.teams[teamId])
    self.teams[teamId] = value
    self:callListeners("onTeamChange", teamId, value)
end

function TeamManager:getTeam(teamId)
    return self.teams[teamId]
end

function TeamManager:getAllTeams()
    return self.teams
end

function TeamManager:serialize()
    local retVal = {}
    local teams = SCEN_EDIT.deepcopy(self.teams)
    for id, team in pairs(teams) do
        team.allies = {}
        for _, team2 in pairs(teams) do
            if Spring.AreTeamsAllied(team.id, team2.id) then
                table.insert(team.allies, team2.id)
            end
        end
        table.insert(retVal, 
            {
                team = team,
                id = id,
            }
        )
    end
    return retVal
end

function TeamManager:load(data)
    self:clear()
    for _, kv in pairs(data) do
        local id = kv.id
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
        Spring.SetTeamColor(team.id, team.color.r, team.color.g, team.color.b)
        team.allies = nil

        self:addTeam(team, id)
    end
end

function TeamManager:clear()
    for teamId, _ in pairs(self.teams) do
        self:removeTeam(teamId)
    end
    self.teamIdCount = 0
end

function TeamManager:generateTeams(widget)
    local teams = SCEN_EDIT.GetTeams(widget)
    self.teams = {}
    for _, team in pairs(teams) do
        self.teams[team.id] = team
    end
end
