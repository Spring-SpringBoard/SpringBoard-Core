SaveCommand = AbstractCommand:extends{}
SaveCommand.className = "SaveCommand"

function SaveCommand:init(path)
    self.className = "SaveCommand"	
    self.path = path
	--add extension if it doesn't exist
	if string.sub(self.path,-string.len(SCEN_EDIT_FILE_EXT)) ~= SCEN_EDIT_FILE_EXT then
		self.path = self.path .. SCEN_EDIT_FILE_EXT
	end
end

local function HeightMapSave(path)
    Spring.Echo("HEIGHTMAP SAVE")
    local file = assert(io.open(path, "wb"))
    local data = {}
    local totalChanged = 0

    local bufferSize = 1000
    local bufferFlush = function()
        if #data == 0 then
            return
        end
        --Spring.Echo("Packing...")
        local str = VFS.PackF32(data)
        --Spring.Echo("Unpacking...")
        local newData = VFS.UnpackF32(str, 1, #str / 4)
        --Spring.Echo(#data, #newData)
        if #data ~= #newData then
            --Spring.Echo("Different size!: ", #data, #newData)
        end
        local diffCount = 0
        for i = 1, math.min(#data, #newData) do
            if data[i] ~= newData[i] then
                diffCount = diffCount + 1
                --Spring.Echo("DIFF:", data[i], newData[i])
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
        local lastChanged = false
        for z = 0, Game.mapSizeZ, Game.squareSize do
            local groundHeight = Spring.GetGroundHeight(x, z)
            local origGroundHeight = Spring.GetGroundOrigHeight(x, z)
            local deltaHeight = groundHeight - origGroundHeight
            if deltaHeight ~= 0 then
                --Spring.Echo(x, z)
                if lastChanged then
                    --Spring.Echo(deltaHeight)
                    if deltaHeight ~= deltaHeight then
                        --Spring.Echo(x, z)
                    end
                    addData(deltaHeight)
                else
                    --Spring.Echo(x, z, deltaHeight)
                    if deltaHeight ~= deltaHeight or x ~= x or z ~= z then
                        --Spring.Echo(x, z, deltaHeight)
                    end
                    addData(x)
                    addData(z)
                    addData(deltaHeight)
                    lastChanged = true
                end
            else
                if lastChanged then
                    --Spring.Echo(0)
                    addData(0)
                    lastChanged = false
                end
            end
        end
    end
    bufferFlush()
    if totalChanged == 0 then
        Spring.Echo("Heightmap unchanged")
    end
    Spring.Echo("Floats: " .. totalChanged)
    Spring.Echo("HEIGHTMAP SAVE DONE")
    assert(file:close())
end

local function ModelSave(path)
    Spring.Echo("calling model save...")
    success, msg = pcall(Model.Save, SCEN_EDIT.model, path)
    if not success then 
        Spring.Echo(msg)
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
	local scenarioInfo = SCEN_EDIT.model.scenarioInfo
	Spring.Echo(scenarioInfo.name)
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

local function GenerateScriptTxt()
	local scriptTxt = 
[[
[GAME]
{
	MapName=Fields_Of_Isis;
	StartMetal=1000;
	StartEnergy=1000;
	StartposType=3;
	GameMode=0;
	GameType=Tutorial - Running Start r184;
	LimitDGun=0;
	DiminishingMMs=0;
	GhostedBuildings=1;
	HostIP=127.0.0.1;
	HostPort=8452;
	IsHost=1;
	MyPlayerNum=0;
	MyPlayerName=Player;
	NumPlayers=1;
	NumTeams=3;
	NumUsers=3;
	NumRestrictions=0;
	MaxSpeed=20;
	MinSpeed=0.1;
	[MODOPTIONS]
	{

	}
	[PLAYER0]
	{
		Name=Player;
		Spectator=0;
		Team=0;
	}
	[AI1]
	{
		Name=Hostiles;
		ShortName=NullAI;
		Team=1;
		IsFromDemo=0;
		Host=0;
		[Options] {}
	}
	[AI2]
	{
		Name=Allies;
		ShortName=NullAI;
		Team=2;
		IsFromDemo=0;
		Host=0;
		[Options] {}
	}
	[TEAM0]
	{
		TeamLeader=0;
		AllyTeam=0;
		RGBColor=0 0 1;
		Side=Robots;
		Handicap=0;
		StartPosX=0;
		StartPosZ=0;
	}
	[TEAM1]
	{
		TeamLeader=0;
		AllyTeam=1;
		RGBColor=1 0 0;
		Side=Robots;
		Handicap=0;
		StartPosX=0;
		StartPosZ=0;
	}
	[TEAM2]
	{
		TeamLeader=0;
		AllyTeam=0;
		RGBColor=0.03560131 0.3231432 0.001214108;
		Side=Robots;
		Handicap=0;
		StartPosX=0;
		StartPosZ=0;
	}
	[ALLYTEAM0]
	{
		NumAllies=0;
	}
	[ALLYTEAM1]
	{
		NumAllies=0;
	}
}

]]

	return scriptTxt
end

local function ModInfoSave(path)
	local modInfoTxt = GenerateModInfo()
	local file = assert(io.open(path, "w"))
	file:write(modInfoTxt)
	file:close()
end

function SaveCommand:execute()
	if VFS.FileExists(self.path) then
		Spring.Echo("file exists... removing")
		os.remove(self.path)
	end	
    assert(not VFS.FileExists(self.path), "File already exists")
   
    Spring.Echo("creating dir...")
    --create a temporary directory
    local tempDirBaseName = "temp/_scen_edit_tmp_"
    local tempDirName = nil
    local indx = 1
    repeat
        tempDirName = tempDirBaseName .. tostring(indx)
    until not VFS.FileExists(tempDirName)
    Spring.CreateDir(tempDirName)

    Spring.Echo("saving files...")
    --save into a temporary directory
    ModelSave(tempDirName .. "/model.lua")
	ModInfoSave(tempDirName .. "/modinfo.lua")
    HeightMapSave(tempDirName .. "/heightmap.data")	

    Spring.Echo("compressing folder...")
    --create an archive from the directory
    VFS.CompressFolder(tempDirName, "zip", self.path)
    --remove the temporary directory
	--FIXME: doesn't work on windows...
    os.remove(tempDirName)
	Spring.Echo("finish")
end
