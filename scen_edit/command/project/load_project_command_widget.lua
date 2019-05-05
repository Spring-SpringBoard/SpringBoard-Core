LoadProjectCommandWidget = Command:extends{}
LoadProjectCommandWidget.className = "LoadProjectCommandWidget"

function LoadProjectCommandWidget:execute()
    Log.Notice("Loading project...")

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
    local cmds = { LoadTextureCommand("sb_texturemap/") }

    if VFS.FileExists("sb_gui.lua", VFS.ZIP) then
        table.insert(cmds, LoadGUIStateCommand(VFS.LoadFile("sb_gui.lua", VFS.ZIP)))
    end

    local cmd = CompoundCommand(cmds)
    SB.commandManager:execute(cmd, true)
end