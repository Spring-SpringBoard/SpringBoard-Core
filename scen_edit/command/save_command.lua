SaveCommand = Command:extends{}
SaveCommand.className = "SaveCommand"

function SaveCommand:init(path, isNewProject)
    self.className = "SaveCommand"
    self.path = path
    self.isNewProject = isNewProject
end

local function HeightMapSave(path)
    local file = assert(io.open(path, "wb"))
    local data = {}
    local totalChanged = 0

    local bufferSize = 100000
    local bufferFlush = function()
        if #data == 0 then
            return
        end
        --Log.Notice("Packing...")
        local str = VFS.PackF32(data)
        --Log.Notice("Unpacking...")
        local newData = VFS.UnpackF32(str, 1, #str / 4)
        --Log.Notice(#data, #newData)
        if #data ~= #newData then
            --Log.Notice("Different size!: ", #data, #newData)
        end
        local diffCount = 0
        for i = 1, math.min(#data, #newData) do
            if data[i] ~= newData[i] then
                diffCount = diffCount + 1
                --Log.Notice("DIFF:", data[i], newData[i])
            end
            if diffCount > 100 then
                break
            end
        end
        file:write(str)
    end
    local addData = function(chunk)
        data[#data + 1] = chunk
        totalChanged = totalChanged + 1
        if #data >= bufferSize then
            bufferFlush()
            data = {}
        end
    end
    for x = 0, Game.mapSizeX, Game.squareSize do
        for z = 0, Game.mapSizeZ, Game.squareSize do
            addData(Spring.GetGroundHeight(x, z))
        end
    end
    bufferFlush()
    if totalChanged == 0 then
        --Log.Notice("Heightmap unchanged")
    end
    --Log.Notice("Heightmap data: " .. totalChanged)
    assert(file:close())
end

local function ModelSave(path)
    success, msg = pcall(Model.Save, SB.model, path)
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
	version	= "__VERSION__",
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
        play_mode = not dev,
    }
    if dev and SB.projectDir then
        modOptions.project_dir = SB.projectDir
    end

    local teams = {}
    local ais = {}
    local players = {}
    for _, team in pairs(SB.model.teamManager:getAllTeams()) do
        if not team.gaia then
            table.insert(teams, {
                -- TeamID = team.id, ID is implicit as index-1
                TeamLeader = 0,
                AllyTeam = team.allyTeam,
                RGBColor = team.color.r .. " " .. team.color.g .. " " .. team.color.b,
            })
        end
        if team.ai then
            local aiShortName = "NullAI"
            local aiVersion = ""
            if not dev then
                -- TODO: Support other AIs for non-dev scripts
            end

            table.insert(ais, {
                Name = team.name,
                Team = team.id - 1,
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
                Team = team.id - 1,
                Spectator = spectator,

                IsFromDemo = true,
            })
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
        if not SB.editorRegistry[name].dont_save then
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
        HeightMapSave(Path.Join(projectDir, "heightmap.data"))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved heightmap"):format(elapsed))
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

    Spring.SendCommands("console 0")

    if #SB.model.textureManager.mapFBOTextures > 0 then
        local texturemapDir = Path.Join(projectDir, "texturemap")
        Spring.CreateDir(texturemapDir)
        local cmd = SaveImagesCommand(texturemapDir, self.isNewProject)
        cmd:execute()
    end

    SB.RequestScreenshotPath = Path.Join(projectDir, SB_SCREENSHOT_FILE)

    SB.projectLoaded = true
end
