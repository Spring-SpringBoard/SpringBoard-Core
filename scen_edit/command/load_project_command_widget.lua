LoadProjectCommandWidget = AbstractCommand:extends{}
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
        SCEN_EDIT.projectDir = self.path
        Log.Notice("set widget project dir:", SCEN_EDIT.projectDir)
        SCEN_EDIT.commandManager:execute(WidgetSetProjectDirCommand(SCEN_EDIT.projectDir), true)
    end

    if isZip then
        Log.Notice("Loading archive: " .. path .. " ...")

        if not VFS.FileExists(path, VFS.RAW) then
            Log.Error("Archive doesn't exist: " .. path)
            return
        end

        if VFS.UnmapArchive and SCEN_EDIT.loadedArchive ~= nil then
            VFS.UnmapArchive(SCEN_EDIT.loadedArchive)
        end

        VFS.MapArchive(path)
        SCEN_EDIT.loadedArchive = path
        modelData = VFS.LoadFile("model.lua", VFS.ZIP)
        heightmapData = VFS.LoadFile("heightmap.data", VFS.ZIP)
        texturePath = "texturemap/"
    else
        Log.Notice("Loading project: " .. path .. " ...")

        if not SCEN_EDIT.DirExists(path, VFS.RAW) then
            Log.Error("Project doesn't exist: " .. path)
            return
        end

        modelData = VFS.LoadFile(Path.Join(path, "model.lua"), VFS.RAW)
        heightmapData = VFS.LoadFile(Path.Join(path, "heightmap.data"), VFS.RAW)
        texturePath = Path.Join(path, "texturemap/")
    end

    local cmds = { LoadMap(heightmapData), LoadModelCommand(modelData)}
    if not hasScenarioFile and Spring.GetGameRulesParam("sb_gameMode") == "play" then
        table.insert(cmds, StartCommand())
    end
    local cmd = CompoundCommand(cmds)
    cmd.blockUndo = true
    SCEN_EDIT.commandManager:execute(cmd)
    SCEN_EDIT.commandManager:execute(LoadTextureCommand(texturePath), true)

    Log.Notice("Load complete.")
end
