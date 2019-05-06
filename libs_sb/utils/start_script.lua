StartScript = StartScript or {}
-- requires table.lua
-- requires string.lua

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
-- DEFUNCT (TODO...)
function StartScript.SmartGen(opts)
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

    -- local myPlayerName = opts.myPlayerName
    -- if not myPlayerName then
    --     assert(Spring.GetMyPlayerID,
    --         "myPlayerName not set and script generation invoked in synced Lua state.")

    --     for _, player in pairs(Spring.GetPlayerRoster()) do
    --         if Spring.GetMyPlayerID() == player.playerID then
    --             myPlayerName = player.name
    --         end
    --     end
    -- end

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
            if isAiTeam and teamID ~= Spring.GetGaiaTeamID() then
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

    local allyTeamCount = 0
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
                    AllyTeam = allyTeamCount,
                    RGBColor = tostring(color[1]) .. " " ..
                        tostring(color[2]) .. " " .. tostring(color[3]),
                })
                allyTeamCount = allyTeamCount + 1
            end
        end
        for _, ai in pairs(ais) do
            local color = {0.99609375, 0.546875, 0}
            if Spring.GetTeamColor then
                color = {Spring.GetTeamColor(ai.Team)}
            end
            table.insert(teams, {
                TeamLeader = 0, -- FIXME: should it be 1?
                AllyTeam = allyTeamCount,
                RGBColor = tostring(color[1]) .. " " ..
                    tostring(color[2]) .. " " .. tostring(color[3]),
            })
            allyTeamCount = allyTeamCount + 1
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
        script["team" .. i-1] = team
    end
    for i, allyTeam in pairs(allyTeams) do
        script["allyTeam" .. i-1] = allyTeam
    end

    local scriptTxt = StartScript.__WriteStartScript(script)
    return scriptTxt
end

--- Create a scriptTxt string
-- @tparam table opts Table
-- @tparam string opts.mapName
-- @tparam table opts.game
-- @tparam string opts.game.name
-- @tparam string opts.game.version
-- @tparam bool opts.isHost (optional, default: true)
-- @tparam string hostIP (optional if isHost, engine default: 127.0.0.1)
-- @tparam number hostPort (optional, engine default: 8452)
-- @tparam number startDelay (optional, engine default: 4)
-- @tparam string myPlayerName (optional, default: current player's name if invoked in unsynced)
-- @tparam number startPosType (optional, engine default: 3 (ChooseBeforeGame))
-- @tparam table players
-- @tparam table modOptions
-- @tparam number modOptions.minSpeed (optional, engine default: 0.3)
-- @tparam number modOptions.maxSpeed (optional, engine default: 20.0)
-- @tparam table mapOptions
-- @tparam table mutators
-- For details see https://github.com/spring/spring/blob/develop/rts/Game/GameSetup.cpp
function StartScript.GenerateScriptTxt(opts)
    local isHost = opts.isHost
    if isHost == nil then
        isHost = true
    end

    assert(opts.mapName ~= nil)
    assert(type(opts.game) == 'table')
    assert(type(opts.players) == 'table')
    assert(type(opts.ais) == 'table')
    assert(type(opts.players) == 'table')
    assert(type(opts.teams) == 'table')
    assert(type(opts.allyTeams) == 'table')

    opts.mutators = opts.mutators or {}

    local script = {
        mapName = opts.mapName,
        gameType = opts.game.name .. " " .. opts.game.version,

        mapSeed = opts.mapSeed,

        isHost = isHost,
        hostIP = "127.0.0.1",
        hostPort = opts.hostPort,

        gameStartDelay = opts.startDelay,
        startPosType = opts.startPosType,

        numPlayers = #opts.players,
        numUsers = #opts.players + #opts.ais,

        modOptions = opts.modOptions or {},
        mapOptions = opts.mapOptions or {},
    }

    for i, ai in ipairs(opts.ais) do
        script["ai" .. i-1] = ai
    end
    for i, player in ipairs(opts.players) do
        script["player" .. i-1] = player
    end
    for i, team in ipairs(opts.teams) do
        script["team" .. i-1] = team
    end
    for i, allyTeam in ipairs(opts.allyTeams) do
        script["allyTeam" .. i-1] = allyTeam
    end
    for i, mutator in ipairs(opts.mutators) do
        script["mutator" .. i-1] = mutator
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

-- NOTICE: potentially dangerous to prune empty tables
-- (an empty table might still count as a definition)
local PRUNE_EMPTY_TABLES = false
function StartScript.__WriteTable(key, value, indent)
    if Table.IsEmpty(value) and PRUNE_EMPTY_TABLES then
        return ""
    end

    if indent == nil then
        indent = 0
    end
    local istr = string.rep('\t', indent) -- indent prefix
    local cstr = istr .. '\t'             -- indent for children

    local str =  istr .. '['..key..']\n'
    str = str .. istr .. '{\n'

    local sortedKeys = Table.GetKeys(value)
    table.sort(sortedKeys, function(a, b)
        return a:lower() < b:lower()
    end)

    local hasTables = false
    -- 1) First write basic types
    for _, k in pairs(sortedKeys) do
        local v = value[k]
        if type(v) ~= 'table' then
            if type(v) == "boolean" then
                v = boolToNumber(v)
            end
            str = str .. cstr .. k .. ' = ' .. tostring(v) .. ';\n'
        elseif not hasTables then
            if not PRUNE_EMPTY_TABLES or not Table.IsEmpty(v) then
                hasTables = true
            end
        end
    end

    -- 2) then the tables (purely for aesthetics)
    if hasTables then
        str = str .. '\n'
        for _, k in pairs(sortedKeys) do
            local v = value[k]
            if type(v) == 'table' and (not PRUNE_EMPTY_TABLES or not Table.IsEmpty(v)) then
                str = str .. istr .. StartScript.__WriteTable(k, v, indent+1)
            end
        end
    end


    return str .. istr ..  '}\n\n'
end

function StartScript.__WriteStartScript(script)
    return StartScript.__WriteTable("GAME", script)
end


-- this is basically a simple TDF parser
-- .. for a more civilized world
function StartScript.ParseStartScript(scriptTxt)
    local parsed = {}

    local lines = String.Split(scriptTxt, '\n')
    local stack = {parsed}
    for _, line in ipairs(lines) do
        local result = {ParseTDFLine(line)}
        local lineType = result[1]
        if lineType ~= nil then
            if lineType == 'section' then
                local current = stack[#stack]
                local newTbl = {}
                table.insert(stack, newTbl)
                current[result[2]:lower()] = newTbl
            -- section_push can be ignored
            elseif lineType == 'section_pop' then
                table.remove(stack, #stack)
            elseif lineType == 'assign' then
                local current = stack[#stack]
                current[result[2]:lower()] = result[3]
            end
        end
    end
    parsed = parsed.game

    -- merge tables
    local merged = {}
    local groups = {}
    for k, v in pairs(parsed) do
        local num = k:match('%d+$')
        if num then
            local bare = k:sub(1, -#num - 1) .. 's'
            if groups[bare] == nil then
                groups[bare] = {}
            end
            table.insert(groups[bare], {
                num = tonumber(num),
                v = v
            })
        else
            merged[k] = v
        end
    end
    for bare, group in pairs(groups) do
        local tbl = {}
        local sorted = Table.SortByAttr(group, 'num')
        for _, item in pairs(sorted) do
            table.insert(tbl, item.v)
        end
        merged[bare] = tbl
    end

    -- fix well know cases
    merged.modOptions = merged.modoptions
    merged.modoptions = nil

    merged.mapOptions = merged.mapoptions
    merged.mapoptions = nil

    merged.mapName = merged.mapname
    merged.mapname = nil

    merged.mapSeed = merged.mapseed
    merged.mapseed = nil

    local name, version = unpack(String.Split(merged.gametype, ' '))
    merged.game = {
        name = name,
        version = version
    }
    merged.gametype = nil

    merged.isHost = merged.ishost
    merged.ishost = nil

    merged.hostIP = merged.hostip
    merged.hostip = nil

    merged.startDelay = merged.gamestartdelay
    merged.gamestartdelay = nil

    merged.myPlayerName = merged.myplayername
    merged.myplayername = nil

    merged.allyTeams = merged.allyteams
    merged.allyteams = nil

    return merged
end

function ParseTDFLine(line)
    line = String.Trim(line)
    if line == '' then
        return
    end

    local section = line:match("%[.*%]")
    if section then
        return "section", section:sub(2, -2)
    end
    if line:find('{') then
        return 'section_push'
    end
    if line:find('}') then
        return 'section_pop'
    end
    local assignLeft = line:match(".*=")
    local assignRight = line:match("=.*;")
    if assignLeft ~= nil and assignRight ~= nil then
        -- We drop the = and ; characters and trim the strings
        assignLeft = String.Trim(assignLeft:sub(1, -2))
        assignRight = String.Trim(assignRight:sub(2, -2))
        return "assign", assignLeft, assignRight
    end
    error("Couldn't parse line: " .. tostring(line))
end