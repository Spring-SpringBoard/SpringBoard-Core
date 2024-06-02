Project = LCS.class.final {
    FOLDER_PREFIX = "sb_project_files/",

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

Project.PROJECT_FILE = Path.Join(Project.FOLDER_PREFIX, "project.lua")
Project.HEIGHTMAP_FILE = Path.Join(Project.FOLDER_PREFIX, "heightmap.data")
Project.MODEL_FILE = Path.Join(Project.FOLDER_PREFIX, "model.lua")
Project.GRASS_FILE = Path.Join(Project.FOLDER_PREFIX, "grass.data")
Project.METAL_FILE = Path.Join(Project.FOLDER_PREFIX, "metal.data")
Project.SCRIPT_FILE = Path.Join(Project.FOLDER_PREFIX, "script.txt")

Project.GUI_FILE = Path.Join(Project.FOLDER_PREFIX, "gui.lua")
Project.ZKCONFIG_FILE = Path.Join(Project.FOLDER_PREFIX, "zkconfig.lua")
Project.SCREENSHOT_FILE = Path.Join(Project.FOLDER_PREFIX, "screenshot.jpg")
Project.TEXTURES_FOLDER = Path.Join(Project.FOLDER_PREFIX, "textures/")

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
    local isNewProject = self:__MaybeSetNameCommand(name)
    assert(self.path ~= nil, "Project path is not specified")
    assert(self.name ~= nil, "Project name is not specified")
    if isNewProject then
        self:GenerateNewProjectInfo(self.name)
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

function Project:GenerateNewProjectInfo(name)
    assert(name ~= nil, "Project path is not specified")
    self.name = nil
    self.path = nil
    self:__MaybeSetNameCommand(name)

    SB.project.mutators = { SB.project.name .. " 1.0" }
    SB.project:CreateProjectStructure(self.path)
    Log.Notice("Saving project info: " .. self.path .. " ...")
    local cmd = SaveProjectInfoCommand(self.name, self.path, true)
    SB.commandManager:execute(cmd, true)
end

function Project:__MaybeSetNameCommand(name)
    if name == nil then
        return false
    end

    local path
    name, path = Project.GenerateNamePath(name)
    if path == self.path then
        return false
    end

	local cmd = SetProjectNamePathCommand(name, path)
	SB.commandManager:execute(cmd)
	SB.commandManager:execute(cmd, true)

    return true
end

function Project.GenerateNamePath(name)
    assert(name ~= nil, "Project needs a name.")

    if String.Ends(name, ".sdd") then
        name = name:sub(1, #name - #(".sdd"))
    end
    local path = Path.Join(SB.DIRS.PROJECTS, name .. ".sdd")

    return name, path
end

function Project:CreateProjectStructure()
    -- create project if it doesn't exist already
    if SB.DirExists(self.path, VFS.RAW) then
        return
	end

    Spring.CreateDir(self.path)
    Spring.CreateDir(Path.Join(self.path, Project.FOLDER_PREFIX))
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
    project:_LoadFromMapOpts()
    project:_LoadFromModOpts()
    project:_LoadFromFile()
    return project
end

function Project:_LoadFromMapOpts()
    local mapOpts = Spring.GetMapOptions()
    if mapOpts.new_map_x ~= nil and mapOpts.new_map_y ~= nil then
        self.randomMapOptions.new_map_x = tonumber(mapOpts.new_map_x)
        self.randomMapOptions.new_map_y = tonumber(mapOpts.new_map_y)
        -- FIXME: Not the real mapseed but probably not an issue either as we don't use it directly in SB
        self.randomMapOptions.mapSeed = 42
    end
end

function Project:_LoadFromModOpts()
    local modOpts = Spring.GetModOptions()
    if modOpts.project_path ~= nil then
        self:SetPath(modOpts.project_path)
    end
end

function Project:_LoadFromFile()
    local success, sbProject
    -- FIXME: We're using a different load path for LuaUI because Spring sometimes doesn't detect new files on Reload
    if Script.GetName() == "LuaUI" and self.path then
        success, sbProject = pcall(VFS.Include, Path.Join(self.path, Project.PROJECT_FILE), nil, VFS.RAW)
    else
        success, sbProject = pcall(VFS.Include, Project.PROJECT_FILE, nil, VFS.ZIP)
    end
    if not success then
        return
    end
    for k, v in pairs(sbProject) do
        self[k] = v
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

-- Checks whether directory is a SpringBoard project
function Project.IsDirProject(path)
    if not String.Ends(path, ".sdd") and
       not String.Ends(path, ".sdd/") and
       not String.Ends(path, ".sdd\\") then
        return false
    end
    if not (VFS.FileExists(path, VFS.RAW) or
            SB.DirExists(path, VFS.RAW)) then
        return false
    end

    return VFS.FileExists(Path.Join(path, Project.PROJECT_FILE), VFS.RAW)
end
