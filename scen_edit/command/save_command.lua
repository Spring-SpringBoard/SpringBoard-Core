SaveCommand = Command:extends{}
SaveCommand.className = "SaveCommand"

function SaveCommand:init(path, isNewProject)
    self.path = path
    self.isNewProject = isNewProject
end

local gameMapSizeX, gameMapSizeZ = Game.mapSizeX, Game.mapSizeZ
local gameSquareSize = Game.squareSize
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGrass = Spring.GetGrass
local spGetMetalAmount = Spring.GetMetalAmount

local function SaveHeightMap(path)
    Array.SaveFunc(path, function(arrayWriter)
        for x = 0, gameMapSizeX, gameSquareSize do
            for z = 0, gameMapSizeZ, gameSquareSize do
                arrayWriter.Write(spGetGroundHeight(x, z))
            end
        end
    end)
end

local function SaveGrassMap(path)
    Array.SaveFunc(path, function(arrayWriter)
        for x = 0, gameMapSizeX, gameSquareSize do
            for z = 0, gameMapSizeZ, gameSquareSize do
                arrayWriter.Write(spGetGrass(x, z))
            end
        end
    end, "uint8")
end

local METAL_RESOLUTION = 16
local function SaveMetalMap(path)
    Array.SaveFunc(path, function(arrayWriter)
        for x = 0, Game.mapSizeX, METAL_RESOLUTION do
            local rx = math.round(x/METAL_RESOLUTION)
            for z = 0, Game.mapSizeZ, METAL_RESOLUTION do
                local rz = math.round(z/METAL_RESOLUTION)
                arrayWriter.Write(spGetMetalAmount(rx, rz))
            end
        end
    end)
end

local function ModelSave(path)
    local success, msg = pcall(Model.Save, SB.model, path)
    if not success then
        Log.Error(msg)
    end
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
    local game
    if not dev then
        game = {}
        game.name = SB.model.scenarioInfo.name
        game.version = SB.model.scenarioInfo.version
    end

    local modOptions = {
        deathmode = "neverend",
        has_scenario_file = not dev,
    }
    if dev then
        modOptions.sb_game_mode = "dev"
    else
        modOptions.sb_game_mode = "play"
    end
    if dev and SB.projectDir then
        modOptions.project_dir = SB.projectDir
    end

    local teams = {}
    local ais = {}
    local players = {}
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        if not team.gaia then
            teams[team.id] = {
                -- TeamID = team.id, ID is implicit as index-1
                TeamLeader = 0,
                AllyTeam = team.allyTeam,
                RGBColor = team.color.r .. " " .. team.color.g .. " " .. team.color.b,
                Side = team.side,
            }
            if String.Trim(team.side) == "" then
                teams[team.id].Side = nil
            end
            if team.ai then
                local aiShortName = "NullAI"
                local aiVersion = ""
                -- if not dev then
                    -- TODO: Support other AIs for non-dev scripts
                -- end

                table.insert(ais, {
                    Name = team.name,
                    Team = team.id,
                    ShortName = aiShortName,
                    Version = aiVersion,

                    IsFromDemo = false,
                    Host = 0,
                })
            else
                local spectator = false
                if dev then
                    spectator = true
                end
                table.insert(players, {
                    Name = team.name,
                    Team = team.id,
                    Spectator = spectator,
                    IsFromDemo = true,
                })
            end
        end
    end

    local scriptTxt = StartScript.GenerateScriptTxt({
        game = game,
        modOptions = modOptions,
        teams = teams,
        players = players,
        ais = ais,
    })
    return scriptTxt
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

local function GUIStateSave(path)
    local brushes = {}
    for name, brushManager in pairs(SB.model.brushManagers:GetBrushManagers()) do
        brushes[name] = brushManager:Serialize()
    end

    local editors = {}
    for name, editor in pairs(SB.editors) do
        if not SB.editorRegistry[name].no_serialize then
            editors[name] = editor:Serialize()
        end
    end

    local guiState = {
        brushes = brushes,
        editors = editors,
    }
    table.save(guiState, path)
end

local function SBInfoSave(path)
    local sbInfo = {
        game = {
            name = Game.gameName,
            version = Game.gameVersion,
        },
        mapName = Game.mapName,
    }

    table.save(sbInfo, path)
end

function SaveCommand:execute()
    local projectDir = self.path

    -- save files
    Time.MeasureTime(function()
        ModelSave(Path.Join(projectDir, "model.lua"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved model"):format(elapsed))
    end)

    Time.MeasureTime(function()
        ModInfoSave(Path.Join(projectDir, "modinfo.lua"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved modinfo"):format(elapsed))
    end)

    Time.MeasureTime(function()
        SaveHeightMap(Path.Join(projectDir, "heightmap.data"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved heightmap"):format(elapsed))
    end)

    Time.MeasureTime(function()
        SaveMetalMap(Path.Join(projectDir, "metal.data"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved metalmap"):format(elapsed))
    end)

    Time.MeasureTime(function()
        SaveGrassMap(Path.Join(projectDir, "grass.data"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved grass"):format(elapsed))
    end)

    Time.MeasureTime(function()
        ScriptTxtSave(Path.Join(projectDir, "script.txt"))
        ScriptTxtSave(Path.Join(projectDir, "script-dev.txt"), true)
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved start scripts"):format(elapsed))
    end)

    Time.MeasureTime(function()
        GUIStateSave(Path.Join(projectDir, "sb_gui.lua"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved GUI state"):format(elapsed))
    end)

    Time.MeasureTime(function()
        SBInfoSave(Path.Join(projectDir, "sb_info.lua"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved SpringBoard info"):format(elapsed))
    end)

    -- Hide the console (FIXME: game agnostic way)
    -- Spring.SendCommands("console 0")

    if #SB.model.textureManager.mapFBOTextures > 0 then
        local texturemapDir = Path.Join(projectDir, "texturemap")
        Spring.CreateDir(texturemapDir)
        local cmd = SaveImagesCommand(texturemapDir, self.isNewProject)
        cmd:execute()
    end

    SB.RequestScreenshotPath = Path.Join(projectDir, SB_SCREENSHOT_FILE)

    SB.projectLoaded = true
end
