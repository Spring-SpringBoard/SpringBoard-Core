LoadProjectCommandWidget = Command:extends{}
LoadProjectCommandWidget.className = "LoadProjectCommandWidget"

function LoadProjectCommandWidget:init(path, isZip)
    self.className = "LoadProjectCommandWidget"
    self.path = path
    self.isZip = isZip
end

-- function LoadProjectCommandWidget:__ReloadInto(game, mapName)
-- 	local scriptTxt = StartScript.GenerateScriptTxt({
--         game = game,
--         mapName = mapName,
--     })
-- 	Spring.Echo(scriptTxt)
-- 	Spring.Reload(scriptTxt)
-- end

function LoadProjectCommandWidget:execute()
    if not self.isZip then
        SB.projectDir = self.path
        Log.Notice("set widget project dir:", SB.projectDir)
        SB.commandManager:execute(WidgetSetProjectDirCommand(SB.projectDir), true)
    end

    -- Check if archive exists
    if not self:__CheckExists() then
        return
    end

    -- Check if we're using the correct editor and map
    if not self:__CheckCorrectEditorAndMap() then
        return
    end

    local texturePath
    if self.isZip then
        Log.Notice("Loading archive: " .. self.path .. " ...")
        self:__LoadArchive(self.path)
        texturePath = "texturemap/"
    else
        Log.Notice("Loading project: " .. self.path .. " ...")
        texturePath = Path.Join(self.path, "texturemap/")
    end

    local modelData = self:__LoadFile("model.lua")
    local heightmapData = self:__LoadFile("heightmap.data")
    local guiState = self:__LoadFile("sb_gui.lua")

    local cmds = {LoadMapCommand(heightmapData), LoadModelCommand(modelData)}
    if not hasScenarioFile and Spring.GetGameRulesParam("sb_gameMode") == "play" then
        table.insert(cmds, StartCommand())
    end
    local cmd = CompoundCommand(cmds)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)
    SB.commandManager:execute(LoadTextureCommand(texturePath), true)
    SB.commandManager:execute(LoadGUIStateCommand(guiState), true)

    Log.Notice("Load complete.")
end

function LoadProjectCommandWidget:__CheckExists()
    if self.isZip then
        if not VFS.FileExists(self.path, VFS.RAW) then
            Log.Error("Archive doesn't exist: " .. self.path)
            return false
        end
    else
        if not SB.DirExists(self.path, VFS.RAW) then
            Log.Error("Project doesn't exist: " .. self.path)
            return false
        end
    end
    return true
end

function LoadProjectCommandWidget:__CheckCorrectEditorAndMap()
    if self.isZip then
        self:__LoadArchive(self.path)
    end

    local sbInfo = self:__LoadFile("sb_info.lua")
    local sbInfo = loadstring(sbInfo)()
    local game, mapName = sbInfo.game, sbInfo.mapName
    if game.name ~= Game.gameName or mapName ~= Game.mapName then
        Log.Notice("Different game (" .. game.name .. " " .. game.version ..
            ") or map (" .. mapName .. "). Reloading into project...")

        local scriptTxt = self:__LoadFile("script-dev.txt")
        Spring.Reload(scriptTxt)

        return false
    end
    return true
end

function LoadProjectCommandWidget:__LoadFile(fname)
    if self.isZip then
        return VFS.LoadFile(fname, VFS.ZIP)
    else
        return VFS.LoadFile(Path.Join(self.path, fname), VFS.RAW)
    end
end

function LoadProjectCommandWidget:__LoadArchive(path)
    if SB.loadedArchive ~= path then
        if VFS.UnmapArchive then
            VFS.UnmapArchive(SB.loadedArchive)
        end
        VFS.MapArchive(path)
        SB.loadedArchive = path
    end
end
