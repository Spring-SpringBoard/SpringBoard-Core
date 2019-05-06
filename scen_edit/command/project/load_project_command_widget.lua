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

    if VFS.FileExists(Project.HEIGHTMAP_FILE, VFS.ZIP) then
        table.insert(cmds, LoadMapCommand(VFS.LoadFile(Project.HEIGHTMAP_FILE, VFS.ZIP)))
    end

    if VFS.FileExists(Project.MODEL_FILE, VFS.ZIP) then
        table.insert(cmds, LoadModelCommand(VFS.LoadFile(Project.MODEL_FILE, VFS.ZIP)))
    end

    if VFS.FileExists(Project.GRASS_FILE, VFS.ZIP) then
        table.insert(cmds, LoadGrassMapCommand(VFS.LoadFile(Project.GRASS_FILE, VFS.ZIP)))
    end

    if VFS.LoadFile(Project.METAL_FILE, VFS.ZIP) then
        table.insert(cmds, LoadMetalMapCommand(VFS.LoadFile(Project.METAL_FILE, VFS.ZIP)))
    end

    if Spring.GetGameRulesParam("sb_gameMode") == "play" then
        table.insert(cmds, StartCommand())
    end

    local cmd = CompoundCommand(cmds)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)
end

function LoadProjectCommandWidget:_LoadUnsynced()
    local cmds = { LoadTextureCommand(Project.TEXTURES_FOLDER) }

    if VFS.FileExists(Project.GUI_FILE, VFS.ZIP) then
        table.insert(cmds, LoadGUIStateCommand(VFS.LoadFile(Project.GUI_FILE, VFS.ZIP)))
    end

    local cmd = CompoundCommand(cmds)
    SB.commandManager:execute(cmd, true)
end