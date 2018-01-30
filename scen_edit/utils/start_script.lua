StartScript = StartScript or {}

-- opts:
-- mapName (optional, default: Game.mapName)
-- game (optional, default: { name = Game.gameName, version = Game.gameVersion})
-- isHost (optional, default: true)
-- hostIP (optional if isHost, engine default: 127.0.0.1)
-- hostPort (optional, engine default: 8452)
-- startDelay (optional, engine default: 4)
-- myPlayerName (optional, default: current player's name if invoked in unsynced)
-- startPosType (optional, engine default: 3 (ChooseBeforeGame))
-- players (optional, )
-- modOptions (optional, default: {})
-- modOptions.minSpeed (optional, engine default: 0.3)
-- modOptions.maxSpeed (optional, engine default: 20.0)
-- mapOptions (optional, default: {})
-- For details see https://github.com/spring/spring/blob/develop/rts/Game/GameSetup.cpp
function StartScript.GenerateScriptTxt(opts)
    local mapFullName = opts.mapName or Game.mapName

    local gameFullName
    if opts.game then
        gameFullName = opts.game.name .. " " .. opts.game.version
    else
        gameFullName = Game.gameName .. " " .. Game.gameVersion
    end

    local isHost = opts.isHost
    if isHost == nil then
        isHost = true
    end

    local myPlayerName = opts.myPlayerName
    if not myPlayerName then
        assert(Spring.GetMyPlayerID,
            "myPlayerName not set and script generation invoked in synced Lua state.")

        for _, player in pairs(Spring.GetPlayerRoster()) do
            if Spring.GetMyPlayerID() == player.playerID then
                myPlayerName = player.name
            end
        end
    end

    local players = opts.players
    if not players then
        players = {}
        for _, playerID in pairs(Spring.GetPlayerList()) do
            local name, _, spectator, teamID = Spring.GetPlayerInfo(playerID)
            table.insert(players, {
                Name = name,
                Team = teamID,
                IsFromDemo = 0,
                Spectator = spectator,
                rank = 0,
            })
        end
    end

    local ais = opts.ais
    if not ais then
        ais = {}
        for _, teamID in pairs(Spring.GetTeamList())  do
            local _, _, _, isAiTeam = Spring.GetTeamInfo(teamID)
            if isAiTeam then
                local aiInfo = Spring.GetAIInfo(teamID)
                table.insert(ais, {
                    Name = aiInfo.name,
                    Team = teamID,
                    IsFromDemo = 0,
                    ShortName = aiInfo.shortName,
                    Version = aiInfo.version,
                    Host = 0,
                })
            end
        end
    end

    local teams = opts.teams
    if not teams then
        teams = {}
        for _, player in pairs(players) do
            if not player.spectator then
                local color = {0.99609375, 0.546875, 0}
                if Spring.GetTeamColor then
                    color = {Spring.GetTeamColor(player.Team)}
                end
                table.insert(teams, {
                    TeamLeader = 0,
                    AllyTeam = #teams,
                    RGBColor = tostring(color[1]) .. " " ..
                        tostring(color[2]) .. " " .. tostring(color[3]),
                })
            end
        end
        for _, ai in pairs(ais) do
            local color = {0.99609375, 0.546875, 0}
            if Spring.GetTeamColor then
                color = {Spring.GetTeamColor(ai.Team)}
            end
            table.insert(teams, {
                TeamLeader = 0, -- FIXME: should it be 1?
                AllyTeam = #teams,
                RGBColor = tostring(color[1]) .. " " ..
                    tostring(color[2]) .. " " .. tostring(color[3]),
            })
        end
    end

    local allyTeams = opts.allyTeams
    if not allyTeams then
        allyTeams = {}
        for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
            local allyTeamInfo = Spring.GetAllyTeamInfo(allyTeamID)
            if allyTeamInfo.numallies then -- this should filter out the gaia ally team
                table.insert(allyTeams, {
                    NumAllies = allyTeamInfo.numallies,
                })
            end
        end
    end

    local script = {
        MapName = mapFullName,
        GameType = gameFullName,

        IsHost = isHost,
        HostIP = "127.0.0.1",
        HostPort = opts.hostPort,

        GameStartDelay = opts.startDelay,
        StartPosType = opts.startPosType,

        NumPlayers = #players,
        NumUsers = #players + #ais,

        ModOptions = opts.modOptions or {},
        MapOptions = opts.mapOptions or {},
    }

    for i, ai in pairs(ais) do
        script["ai" .. i-1] = ai
    end
    for i, player in pairs(players) do
        script["player" .. i-1] = player
    end
    for i, team in pairs(teams) do
        script["team" .. i] = team
    end
    for i, allyTeam in pairs(allyTeams) do
        script["allyTeam" .. i-1] = allyTeam
    end

    local scriptTxt = StartScript.__WriteStartScript(script)
    return scriptTxt
end

function boolToNumber(bool)
    if bool then
        return 1
    else
        return 0
    end
end

function StartScript.__WriteTable(key, value)
    local str = '\t['..key..']\n\t{\n'
    -- First write Tables
    for k, v in pairs(value) do
        if type(v) == 'table' then
            str = str .. StartScript.__WriteTable(k, v)
        end
    end

    -- Then the rest (purely for aesthetics)
    for k, v in pairs(value) do
        if type(v) ~= 'table' then
            if type(v) == "boolean" then
                v = boolToNumber(v)
            end
            str = str .. '\t\t' .. k .. ' = ' .. tostring(v) .. ';\n'
        end
    end
    return str .. '\t}\n\n'
end

function StartScript.__WriteStartScript(script)
    return StartScript.__WriteTable("GAME", script)
end
