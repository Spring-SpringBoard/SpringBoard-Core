LoadProjectCommandWidget = Command:extends{}
LoadProjectCommandWidget.className = "LoadProjectCommandWidget"

function LoadProjectCommandWidget:init(path)
    self.path = path
end

-- function LoadProjectCommandWidget:__ReloadInto(game, mapName)
--     local scriptTxt = StartScript.GenerateScriptTxt({
--         game = game,
--         mapName = mapName,
--     })
--     Spring.Echo(scriptTxt)
--     Spring.Reload(scriptTxt)
-- end

function LoadProjectCommandWidget:execute()
    SB.project:SetPath(self.path)
    Log.Notice("Set widget project path:", SB.project.path)
    SB.commandManager:execute(WidgetSetProjectDirCommand(SB.project.path), true)

    Log.Notice("Loading project: " .. self.path .. " ...")

    self:_LoadSynced()
    self:_LoadUnsynced()

    -- We don't need the stuff stored in the command classes anymore. Better
    -- we clear that to make room for synced commands
    collectgarbage()

    Log.Notice("Load complete.")
end

function LoadProjectCommandWidget:_LoadSynced()
    local cmds = {}

    if VFS.FileExists("sb_heightmap.data", VFS.ZIP) then
        table.insert(cmds, LoadMapCommand(VFS.LoadFile("sb_heightmap.data", VFS.ZIP)))
    end

    if VFS.FileExists("sb_model.lua", VFS.ZIP) then
        table.insert(cmds, LoadModelCommand(VFS.LoadFile("sb_model.lua", VFS.ZIP)))
    end

    if VFS.FileExists("sb_grass.data", VFS.ZIP) then
        table.insert(cmds, LoadGrassMapCommand(VFS.LoadFile("sb_grass.data", VFS.ZIP)))
    end

    if VFS.LoadFile("sb_metal.data", VFS.ZIP) then
        table.insert(cmds, LoadMetalMapCommand(VFS.LoadFile("sb_metal.data", VFS.ZIP)))
    end

    if not hasScenarioFile and Spring.GetGameRulesParam("sb_gameMode") == "play" then
        table.insert(cmds, StartCommand())
    end

    local cmd = CompoundCommand(cmds)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)
end

function LoadProjectCommandWidget:_LoadUnsynced()
    local cmds = { LoadTextureCommand(Path.Join(self.path, "sb_texturemap/")) }

    if VFS.FileExists("sb_gui.lua", VFS.ZIP) then
        table.insert(cmds, LoadGUIStateCommand(VFS.LoadFile("sb_gui.lua", VFS.ZIP)))
    end

    local cmd = CompoundCommand(cmds)
    SB.commandManager:execute(cmd, true)
end