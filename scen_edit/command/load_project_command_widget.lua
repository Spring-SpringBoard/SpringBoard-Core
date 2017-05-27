LoadProjectCommandWidget = Command:extends{}
LoadProjectCommandWidget.className = "LoadProjectCommandWidget"

function LoadProjectCommandWidget:init(path, isZip)
    self.className = "LoadProjectCommandWidget"
    self.path = path
    self.isZip = isZip
end

function LoadProjectCommandWidget:execute()
    local path = self.path
    local isZip = self.isZip
    local modelData, heightMapdata, texturePath

    if not isZip then
        SB.projectDir = self.path
        Log.Notice("set widget project dir:", SB.projectDir)
        SB.commandManager:execute(WidgetSetProjectDirCommand(SB.projectDir), true)
    end

    if isZip then
        Log.Notice("Loading archive: " .. path .. " ...")

        if not VFS.FileExists(path, VFS.RAW) then
            Log.Error("Archive doesn't exist: " .. path)
            return
        end

        if VFS.UnmapArchive and SB.loadedArchive ~= nil then
            VFS.UnmapArchive(SB.loadedArchive)
        end

        VFS.MapArchive(path)
        SB.loadedArchive = path
        modelData = VFS.LoadFile("model.lua", VFS.ZIP)
        heightmapData = VFS.LoadFile("heightmap.data", VFS.ZIP)
        texturePath = "texturemap/"
    else
        Log.Notice("Loading project: " .. path .. " ...")

        if not SB.DirExists(path, VFS.RAW) then
            Log.Error("Project doesn't exist: " .. path)
            return
        end

        modelData = VFS.LoadFile(Path.Join(path, "model.lua"), VFS.RAW)
        heightmapData = VFS.LoadFile(Path.Join(path, "heightmap.data"), VFS.RAW)
        texturePath = Path.Join(path, "texturemap/")
    end

    local cmds = {LoadMapCommand(heightmapData), LoadModelCommand(modelData)}
    if not hasScenarioFile and Spring.GetGameRulesParam("sb_gameMode") == "play" then
        table.insert(cmds, StartCommand())
    end
    local cmd = CompoundCommand(cmds)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)
    SB.commandManager:execute(LoadTextureCommand(texturePath), true)

    Log.Notice("Load complete.")
end
