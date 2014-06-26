ExportCommand = AbstractCommand:extends{}
ExportCommand.className = "ExportCommand"

function ExportCommand:init(path)
    self.className = "ExportCommand"	
    self.path = path
	--add extension if it doesn't exist
	if string.sub(self.path,-string.len(SCEN_EDIT_FILE_EXT)) ~= SCEN_EDIT_FILE_EXT then
		self.path = self.path .. SCEN_EDIT_FILE_EXT
	end
end

local function GenerateScriptTxt(dev)
    local playMode = 1
    if dev then
        playMode = 0
    end
	local scriptTxt = 
[[
[GAME]
{
	MapName=__MAP_NAME__;
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
	MyPlayerNum=1;
	MyPlayerName=Player;
	NumRestrictions=0;
	MaxSpeed=20;
	MinSpeed=0.1;
	[MODOPTIONS]
	{
        play_mode = __PLAY_MODE__;
        deathmode = neverend;
        has_scenario_file = __HAS_SCENARIO_FILE__;
        __PROJECT_DIR__
	}

]]

    local scenarioInfo = SCEN_EDIT.model.scenarioInfo
    local gameType = nil
    local projectDir = ""
    if not dev then
        gameType = scenarioInfo.name .. " " .. scenarioInfo.version
    else
        gameType = Game.gameName .. " " .. Game.gameVersion
        if SCEN_EDIT.model.projectDir then
            projectDir = "project_dir = " .. SCEN_EDIT.model.projectDir .. ";"
        end
    end

    scriptTxt = scriptTxt:gsub("__MAP_NAME__", Game.mapName)
                         :gsub("__GAME_TYPE__", gameType)
                         :gsub("__NUM_USERS__", tostring(#SCEN_EDIT.model.teams))
                         :gsub("__NUM_TEAMS__", tostring(#SCEN_EDIT.model.teams))
                         :gsub("__PLAY_MODE__", tostring(playMode))
                         :gsub("__HAS_SCENARIO_FILE__", tostring(playMode))
                         :gsub("__PROJECT_DIR__", tostring(projectDir))

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

        TeamLeader=1;
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
		Host=1;
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
        Spectator=__SPECTATOR__;
        Team=__TEAM__;
    }
]]
                local spectator = 0
                if dev then
                    spectator = 1
                end
                numPlayers = numPlayers + 1
                playerTxt = playerTxt:gsub("__PLAYER_ID__", "PLAYER" .. numPlayers)
                             :gsub("__NAME__", team.name)
                             :gsub("__SPECTATOR__", spectator)
                             :gsub("__TEAM__", team.id)
                
                scriptTxt = scriptTxt .. playerTxt
            end
        end
    end

    if numPlayers == 0 then
        local playerTxt = [[
    [__PLAYER_ID__]
    {
        Name=__NAME__;
        Spectator=1;
        Team=__TEAM__;
    }
]]
        numPlayers = numPlayers + 1
        playerTxt = playerTxt:gsub("__PLAYER_ID__", "PLAYER" .. numPlayers)
                             :gsub("__NAME__", "Player")
                             :gsub("__TEAM__", 1)

        scriptTxt = scriptTxt .. playerTxt
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

function ExportCommand:execute()
	if VFS.FileExists(self.path) then
		Spring.Echo("File exists, trying to remove...")
		os.remove(self.path)
	end	
    assert(not VFS.FileExists(self.path), "File already exists")
  
    local projectDir = SCEN_EDIT.model:GetProjectDir()
    ScriptTxtSave(SCEN_EDIT.model.scenarioInfo.name .. "-script.txt")
    ScriptTxtSave(SCEN_EDIT.model.scenarioInfo.name .. "-script-DEV.txt", true)

    --Spring.Echo("compressing folder...")
    --create an archive from the directory
    VFS.CompressFolder(projectDir, "zip", self.path)
end
