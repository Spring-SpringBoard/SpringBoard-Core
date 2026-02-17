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

    local file = Path.Join(SB.project.path, Project.HEIGHTMAP_FILE)
    if VFS.FileExists(file, VFS.RAW) then
        table.insert(cmds, LoadMapCommand(VFS.LoadFile(file, VFS.RAW)))
    end

    file = Path.Join(SB.project.path, Project.MODEL_FILE)
    if VFS.FileExists(file, VFS.RAW) then
        table.insert(cmds, LoadModelCommand(VFS.LoadFile(file, VFS.RAW)))
    end

    file = Path.Join(SB.project.path, Project.GRASS_FILE)
    if VFS.FileExists(file, VFS.RAW) then
        table.insert(cmds, LoadGrassMapCommand(VFS.LoadFile(file, VFS.RAW)))
    end

    file = Path.Join(SB.project.path, Project.METAL_FILE)
    if VFS.LoadFile(file, VFS.RAW) then
        table.insert(cmds, LoadMetalMapCommand(VFS.LoadFile(file, VFS.RAW)))
    end

    if Spring.GetGameRulesParam("sb_gameMode") == "play" then
        table.insert(cmds, StartCommand())
    end

    local cmd = CompoundCommand(cmds)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)
end

function LoadProjectCommandWidget:_LoadUnsynced()
    local cmds = { LoadTextureCommand(Path.Join(SB.project.path, Project.TEXTURES_FOLDER)) }

    local file = Path.Join(SB.project.path, Project.GUI_FILE)
    if VFS.FileExists(file, VFS.RAW) then
        table.insert(cmds, LoadGUIStateCommand(VFS.LoadFile(file, VFS.RAW)))
    end

    local file = Path.Join(SB.project.path, Project.ZKCONFIG_FILE)
    if VFS.FileExists(file, VFS.RAW) then
        table.insert(cmds, LoadZKMapConfigCommand(VFS.LoadFile(file, VFS.RAW)))
    end

    local cmd = CompoundCommand(cmds)
    SB.commandManager:execute(cmd, true)
end