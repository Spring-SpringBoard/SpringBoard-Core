Project = LCS.class.final {
    name = nil,
    path = nil,

    game = {
        name = Game.gameName,
        version = Game.gameVersion,
    },
    mapName = Game.mapName,
    randomMapOptions = {},
    mutators = {},
}

function Project:GetData()
    return {
        name = self.name,
        path = self.path,

        game = self.game,
        mapName = self.mapName,
        randomMapOptions = self.randomMapOptions,
        mutators = self.mutators
    }
end

function Project:Save(name)
    local isNewProject = self:__MaybeSetPathCommand(name)
    assert(self.path ~= nil, "Project path is not specified")
    assert(self.name ~= nil, "Project name is not specified")
    if isNewProject then
        SB.project:CreateProjectStructure(self.path)
    end

    Log.Notice("Saving project: " .. self.path .. " ...")

    local cmds = CompoundCommand({
        SaveProjectInfoCommand(self.name, self.path, isNewProject),
        SaveCommand(self.path, isNewProject)
    })
    SB.commandManager:execute(cmds, true)

    -- We delay this notice twice to ensure texture map and screenshot is taken
    SB.delayGL(function()
        SB.delayGL(function()
            Log.Notice("Saved project.")

            if isNewProject then
                SB.commandManager:execute(ReloadIntoProjectCommand(self.path), true)
            end
        end)
    end)
end

function Project:SaveProjectInfo(name)
    local isNewProject = self:__MaybeSetPathCommand(name)
    assert(self.path ~= nil, "Project path is not specified")
    assert(self.name ~= nil, "Project name is not specified")
    if isNewProject then
        SB.project:CreateProjectStructure(self.path)
    end

    Log.Notice("Saving project info: " .. self.path .. " ...")
    local cmd = SaveProjectInfoCommand(self.name, self.path, isNewProject)
    SB.commandManager:execute(cmd, true)
end

function Project:__MaybeSetPathCommand(name)
    if name == nil then
        return false
    end

    if String.Ends(name, ".sdd") then
        name = name:sub(1, #name - #(".sdd"))
    end
    local path = Path.Join(SB_PROJECTS_DIR, name .. ".sdd")
    if path == self.path then
        return false
    end

	local cmd = SetProjectNamePathCommand(name, path)
	SB.commandManager:execute(cmd)
	SB.commandManager:execute(cmd, true)

    return true
end

function Project:CreateProjectStructure()
    -- create project if it doesn't exist already
    if SB.DirExists(self.path, VFS.RAW_ONLY) then
        return
	end

    Spring.CreateDir(self.path)
    Spring.CreateDir(Path.Join(self.path, "triggers"))

    local myCustomTriggersLua = [[
return {
    dataTypes = {
        -- Custom data types go here
    },
    events = {
        -- Custom events go here
    },
    actions = {
        -- Custom actions go here
    },
    functions = {
        -- Custom functions go here
    },
}

]]
    local triggersFile = assert(io.open(Path.Join(self.path, "triggers/my_custom_triggers.lua"), "w"))
    triggersFile:write(myCustomTriggersLua)
	triggersFile:close()
end

function Project.InitializeFromEnvironment()
    local project = Project()
    project:_LoadFromModOpts()
    project:_LoadFromFile()
    return project
end

function Project:_LoadFromFile()
    local success, sbInfo = pcall(VFS.Include, "sb_project.lua", nil, VFS.ZIP)
    if not success then
        return
    end
    for k, v in pairs(sbInfo) do
        self[k] = v
    end
end

function Project:_LoadFromModOpts()
    local modOpts = Spring.GetModOptions()
    if modOpts.project_path ~= nil then
        self:SetPath(modOpts.project_path)
    end
end

function Project:SetPath(path)
    self.path = path
    if Script.GetName() == "LuaUI" then
        Spring.SetWMCaption(self.path)
    end
end

function Project.ParseModOpts()
    -- detect game mode
    local modOpts = Spring.GetModOptions()
    if modOpts.sb_game_mode == nil and modOpts.play_mode ~= nil then
        -- Report outdated script.txt, and use "dev" mode to can update it
        Log.Error("Outdated init script mod option 'play_mode'. " ..
                  "Please, export your project again")
    end
    local sb_gameMode = (modOpts.sb_game_mode or "dev")
    if sb_gameMode ~= "dev" and sb_gameMode ~= "test" and sb_gameMode ~= "play" then
        Log.Error("Unexpected sb_game_mode value: " ..
            sb_gameMode .. ". Defaulting to 'dev'.")
        sb_gameMode = "dev"
    end
    Log.Notice("SpringBoard", "info", "Running SpringBoard in " .. sb_gameMode .. "  gameMode.")
    Spring.SetGameRulesParam("sb_gameMode", sb_gameMode)
end

