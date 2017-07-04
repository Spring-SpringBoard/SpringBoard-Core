ExportCommand = Command:extends{}
ExportCommand.className = "ExportCommand"

function ExportCommand:init(path)
    self.className = "ExportCommand"
    self.path = path
	--add extension if it doesn't exist
	if string.sub(self.path,-string.len(SB_FILE_EXT)) ~= SB_FILE_EXT then
		self.path = self.path .. SB_FILE_EXT
	end
end

local function __GenerateStartScript(dev)
    local game
    if not dev then
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
    local teams = SB.model.teamManager:getAllTeams()

    local scriptTxt = StartScript.GenerateScriptTxt({
        game = game,
        modOptions = modOptions,
        --teams = teams,
    })
end

local function ScriptTxtSave(path, dev)
    local scriptTxt = __GenerateStartScript(dev)
	local file = assert(io.open(path, "w"))
	file:write(scriptTxt)
	file:close()
end

function ExportCommand:execute()
	if VFS.FileExists(self.path) then
		Log.Notice("File exists, trying to remove...")
		os.remove(self.path)
	end
    assert(not VFS.FileExists(self.path), "File already exists")

    local projectDir = SB.projectDir
    ScriptTxtSave(SB.model.scenarioInfo.name .. "-script.txt")
    ScriptTxtSave(SB.model.scenarioInfo.name .. "-script-DEV.txt", true)

    --Log.Notice("compressing folder...")
    --create an archive from the directory
    VFS.CompressFolder(projectDir, "zip", self.path)
end
