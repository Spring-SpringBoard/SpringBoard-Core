SaveProjectInfoCommand = Command:extends{}
SaveProjectInfoCommand.className = "SaveProjectInfoCommand"

function SaveProjectInfoCommand:init(name, path, isNewProject)
    self.name = name
    self.path = path
    self.isNewProject = isNewProject
end

local function GenerateModInfo()
    local modInfoTxt =
[[
local modinfo = {
    name = "__NAME__",
    shortName = "__SHORTNAME__",
    version    = "__VERSION__",
    game = "__GAME__", --what is this?
    shortGame = "__SHORTGAME__", --what is this?
    mutator = "Official", --what is this?
    description = "__DESCRIPTION__",
    modtype = "1",
    depend = {
        "__GAME_NAME__ __GAME_VERSION__",
    }
}
return modinfo]]
    local scenarioInfo = SB.model.scenarioInfo
    modInfoTxt = modInfoTxt:gsub("__NAME__", scenarioInfo.name)
                           :gsub("__SHORTNAME__", scenarioInfo.name)
                           :gsub("__VERSION__", scenarioInfo.version)
                           :gsub("__GAME__", scenarioInfo.name)
                           :gsub("__SHORTGAME__", scenarioInfo.name)
                           :gsub("__DESCRIPTION__", scenarioInfo.description)
                           :gsub("__GAME_NAME__", Game.gameName)
                           :gsub("__GAME_VERSION__", Game.gameVersion)

    return modInfoTxt
end

function SaveCommand.GenerateScript(dev)
    -- TODO: Use SB.GetPersistantModOptions
    local project = SB.project

    local game
    if dev then
        game = {
            name = project.game.name,
            version = project.game.version
        }
    else
        game = {
            name = SB.model.scenarioInfo.name,
            version = SB.model.scenarioInfo.version
        }
    end

    local modOptions = {
        deathmode = "neverend",
        has_scenario_file = not dev,
        _sb_game_name = Game.gameName,
        _sb_game_version = Game.gameVersion,
    }
    if dev then
        modOptions.sb_game_mode = "dev"
    else
        modOptions.sb_game_mode = "play"
    end
    if dev and SB.project.path then
        modOptions.project_path = SB.project.path
    end

    local teams = {}
    local ais = {}
    local players = {}

    -- we ignore SB's teamIDs and make sure they make a no-gap array
    local teamIDCount = 1
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        if not team.gaia then
            local t = {
                -- TeamID = team.id, ID is implicit as index-1
                teamLeader = 0,
                allyTeam = team.allyTeam,
                RGBColor = team.color.r .. " " .. team.color.g .. " " .. team.color.b,
                side = team.side,
            }
            teams[teamIDCount] = t
            if String.Trim(team.side) == "" then
                t.side = nil
            end
            if team.ai then
                local aiShortName = "NullAI"
                local aiVersion = ""
                -- if not dev then
                    -- TODO: Support other AIs for non-dev scripts
                -- end

                table.insert(ais, {
                    name = team.name,
                    team = teamIDCount,
                    shortName = aiShortName,
                    version = aiVersion,

                    isFromDemo = false,
                    host = 0,
                })
            else
                local spectator = false
                if dev then
                    spectator = true
                end
                table.insert(players, {
                    name = team.name,
                    team = teamIDCount,
                    spectator = spectator,
                    isFromDemo = true,
                })
            end

            teamIDCount = teamIDCount + 1
        end
    end

    local allyTeams = {}
    for i = 1, #teams do
        table.insert(allyTeams, {
            numAllies = 1,
        })
    end

    local script = {
        game = game,
        mapName = project.mapName,
        mapSeed = project.randomMapOptions.mapSeed,
        mapOptions = {
            new_map_x = project.randomMapOptions.new_map_x,
            new_map_z = project.randomMapOptions.new_map_z
        },
        startDelay = 0,
        mutators = project.mutators,
        modOptions = modOptions,
        players = players,
        ais = ais,
        teams = teams,
        allyTeams = allyTeams,
    }
    return StartScript.GenerateScriptTxt(script)
end

local function ScriptTxtSave(path, dev)
    local scriptTxt = SaveCommand.GenerateScript(dev)
    local file = assert(io.open(path, "w"))
    file:write(scriptTxt)
    file:close()
end

local function ModInfoSave(path)
    local modInfoTxt = GenerateModInfo()
    local file = assert(io.open(path, "w"))
    file:write(modInfoTxt)
    file:close()
end

local function MapInfoSave(name, path)
    local mapInfo = [[
local mapinfo = {
    name = "$NAME",
    version = "1.0",
    description = "",
    modtype = 3,
    depend = {
        "cursors.sdz",
    }
}

return mapinfo
]]
    mapInfo = mapInfo:gsub("$NAME", name)
    local mapInfoFile = assert(io.open(path, "w"))
    mapInfoFile:write(mapInfo)
    mapInfoFile:close()
end

function SaveProjectInfoCommand:execute()
    local projectDir = self.path
    local projectName = self.name

    Time.MeasureTime(function()
        MapInfoSave(projectName, Path.Join(projectDir, "mapinfo.lua"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved mapinfo"):format(elapsed))
    end)

    Time.MeasureTime(function()
        ScriptTxtSave(Path.Join(projectDir, "script.txt"))
        ScriptTxtSave(Path.Join(projectDir, "script-dev.txt"), true)
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved start scripts"):format(elapsed))
    end)

    Time.MeasureTime(function()
        table.save(SB.project:GetData(), Path.Join(projectDir, "sb_project.lua"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved SpringBoard info"):format(elapsed))
    end)
end
