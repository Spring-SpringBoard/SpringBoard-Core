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
        for x = 0, gameMapSizeX - 1, gameSquareSize * 4 do
            for z = 0, gameMapSizeZ - 1, gameSquareSize * 4 do
                arrayWriter.Write(spGetGrass(x, z))
            end
        end
    end, "uint8")
end

local METAL_RESOLUTION = 16
local function SaveMetalMap(path)
    Array.SaveFunc(path, function(arrayWriter)
        for x = 0, gameMapSizeX - 1, METAL_RESOLUTION do
            local rx = math.round(x/METAL_RESOLUTION)
            for z = 0, gameMapSizeZ - 1, METAL_RESOLUTION do
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

local function ZKconfigSave(path)
    local tbl = {}
	local teamList = {}
    local boxes = SB.model.startboxManager:getAllStartBoxes()
	for boxID, _ in pairs(boxes) do
		local teamID = SB.model.startboxManager:getTeam(boxID)
		local team = SB.model.teamManager:getTeam(teamID)
		if not teamList[teamID] then
			teamList[teamID] = {name = team.name, short = team.short, x = team.x or nil, z = team.z or nil, boxes = {}}
		end
		table.insert(teamList[teamID].boxes, boxID)
    end
	local mexes = SB.model.mexManager:getAllMexes()
	tbl.mexes, tbl.boxes, tbl.teamList = mexes, boxes, teamList
    table.save(tbl, path)
end

function SaveCommand:execute()
    local projectDir = self.path

    -- save files
    Time.MeasureTime(function()
        ModelSave(Path.Join(projectDir, Project.MODEL_FILE))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved model"):format(elapsed))
    end)

    -- Time.MeasureTime(function()
    --     ModInfoSave(Path.Join(projectDir, "modinfo.lua"))
    -- end, function(elapsed)
    --     Log.Notice(("[%.4fs] Saved modinfo"):format(elapsed))
    -- end)

    Time.MeasureTime(function()
        SaveHeightMap(Path.Join(projectDir, Project.HEIGHTMAP_FILE))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved heightmap"):format(elapsed))
    end)

    Time.MeasureTime(function()
        SaveMetalMap(Path.Join(projectDir, Project.METAL_FILE))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved metalmap"):format(elapsed))
    end)

    Time.MeasureTime(function()
        SaveGrassMap(Path.Join(projectDir, Project.GRASS_FILE))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved grass"):format(elapsed))
    end)

    Time.MeasureTime(function()
        GUIStateSave(Path.Join(projectDir, Project.GUI_FILE))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved GUI state"):format(elapsed))
    end)
	
    Time.MeasureTime(function()
        ZKconfigSave(Path.Join(projectDir, Project.ZKCONFIG_FILE))
    end, function(elapsed)
        Log.Notice(("[%.4fs] Saved GUI state"):format(elapsed))
    end)
    -- Hide the console (FIXME: game agnostic way)
    -- Spring.SendCommands("console 0")

    if #SB.model.textureManager.mapFBOTextures > 0 then
        local texturemapDir = Path.Join(projectDir, Project.TEXTURES_FOLDER)
        Spring.CreateDir(texturemapDir)
        SaveImagesCommand(texturemapDir, self.isNewProject):execute()
    end

    SB.RequestScreenshotPath = Path.Join(projectDir, Project.SCREENSHOT_FILE)
end
