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
        --Spring.Echo("Heightmap unchanged")
    end
    --Spring.Echo("Heightmap data: " .. totalChanged)
    assert(file:close())
end

local function ModelSave(path)
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
	MapName=__MAP_NAME__
	GameMode=0;
	GameType=__GAME_TYPE__;


	NumTeams=__NUM_TEAMS__;
	NumUsers=__NUM_USERS__;

	HostIP=127.0.0.1;
	HostPort=8452;
	IsHost=1;
	NumPlayers=1;

	StartMetal=1000;
	StartEnergy=1000;

	StartposType=3;
	LimitDGun=0;
	DiminishingMMs=0;
	GhostedBuildings=1;
	MyPlayerNum=0;
	MyPlayerName=Player;
	NumRestrictions=0;
	MaxSpeed=20;
	MinSpeed=0.1;
	[MODOPTIONS]
	{
        dev = __DEV__;
	}

]]

    local scenarioInfo = SCEN_EDIT.model.scenarioInfo
    scriptTxt = scriptTxt:gsub("__MAP_NAME__", Game.mapName)
                         :gsub("__GAME_TYPE__", scenarioInfo.name .. " " .. scenarioInfo.version)
                         :gsub("__NUM_USERS__", tostring(#SCEN_EDIT.model.teams))
                         :gsub("__NUM_TEAMS__", tostring(#SCEN_EDIT.model.teams))
                         :gsub("__DEV__", tostring((not not dev)))

    local numAIs = 0
    local numPlayers = 0
    for _, team in pairs(SCEN_EDIT.model.teams) do
        if not team.gaia then
            local teamTxt = [[
    [__TEAM_ID__]
    {
        AllyTeam=__ALLY_TEAM__;
        Side=__TEAM_SIDE__;
        RGBColor=__RGB_COLOR__;

        TeamLeader=0;
        Handicap=0;
        StartPosX=0;
        StartPosZ=0;
    }
]]
            teamTxt = teamTxt:gsub("__TEAM_ID__", "TEAM" .. team.id)
                             :gsub("__ALLY_TEAM__", team.allyTeam)
                             :gsub("__TEAM_SIDE__", team.side)
                             :gsub("__RGB_COLOR__", team.color.r .. " " .. team.color.g .. " " .. team.color.b)
            scriptTxt = scriptTxt .. teamTxt
            if team.ai then
                local aiTxt = [[
    [__AI_ID__]
    {
		Name=__NAME__;
		ShortName=__SHORT_NAME__;
		Team=__TEAM__;
		IsFromDemo=0;
		Host=0;
		[Options] {}
    }
]]
                numAIs = numAIs + 1
                aiTxt = aiTxt:gsub("__AI_ID__", "AI" .. numAIs)
                             :gsub("__NAME__", team.name)
                             :gsub("__SHORT_NAME__", "NullAI") -- TODO: support other AIs as well
                             :gsub("__TEAM__", team.id)
                scriptTxt = scriptTxt .. aiTxt
            else
                local playerTxt = [[
    [__PLAYER_ID__]
    {
        Name=__NAME__;
        Spectator=0;
        Team=__TEAM__;
    }
]]
                numPlayers = numPlayers + 1
                playerTxt = playerTxt:gsub("__PLAYER_ID__", "PLAYER" .. numPlayers)
                             :gsub("__NAME__", team.name)
                             :gsub("__TEAM__", team.id)
                
                scriptTxt = scriptTxt .. playerTxt
            end
        end
    end

    for _, allyTeamId in pairs(Spring.GetAllyTeamList()) do
        local allyTeamTxt = [[
    [__ALLYTEAM_ID__]
    {
        NumAllies=0;
    }
]]
        allyTeamTxt = allyTeamTxt:gsub("__ALLYTEAM_ID__", "ALLYTEAM" .. allyTeamId)
        allyTeamInfo = Spring.GetAllyTeamInfo(allyTeamId)
        if allyTeamInfo.numallies then -- this should filter out the gaia ally team
            scriptTxt = scriptTxt .. allyTeamTxt
        end
    end

    scriptTxt = scriptTxt .. "\n}"
	return scriptTxt
end

local function ScriptTxtSave(path, dev)
	local scriptTxt = GenerateScriptTxt(dev)
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

function SaveCommand:execute()
	if VFS.FileExists(self.path) then
		Spring.Echo("File exists, trying to remove...")
		os.remove(self.path)
	end	
    assert(not VFS.FileExists(self.path), "File already exists")
   
    --create a temporary directory
    local tempDirBaseName = "temp/_scen_edit_tmp_"
    local tempDirName = nil
    local indx = 1
    repeat
        tempDirName = tempDirBaseName .. tostring(indx)
    until not VFS.FileExists(tempDirName)
    Spring.CreateDir(tempDirName)

    --Spring.Echo("saving files...")
    --save into a temporary directory
    ModelSave(tempDirName .. "/model.lua")
	ModInfoSave(tempDirName .. "/modinfo.lua")
    HeightMapSave(tempDirName .. "/heightmap.data")	
    ScriptTxtSave(tempDirName .. "/script.txt")
    ScriptTxtSave(tempDirName .. "/script-dev.txt", true)

    --Spring.Echo("compressing folder...")
    --create an archive from the directory
    VFS.CompressFolder(tempDirName, "zip", self.path)
    --remove the temporary directory
	--FIXME: doesn't work on windows...
    os.remove(tempDirName)
end
