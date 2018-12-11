LoadProjectCommandWidget = Command:extends{}
LoadProjectCommandWidget.className = "LoadProjectCommandWidget"

function LoadProjectCommandWidget:init(path, isZip)
    self.path = path
    self.isZip = isZip
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

    local grassData = self:__LoadFile("grass.data")
    if grassData then
        table.insert(cmds, LoadGrassMapCommand(grassData))
    end
    local metalData = self:__LoadFile("metal.data")
    if metalData then
        table.insert(cmds, LoadMetalMapCommand(metalData))
    end

    local cmd = CompoundCommand(cmds)
    cmd.blockUndo = true
    SB.commandManager:execute(cmd)
    SB.commandManager:execute(LoadTextureCommand(texturePath), true)
    SB.commandManager:execute(LoadGUIStateCommand(guiState), true)

    -- We don't need the stuff stored in the command classes anymore. Better
    -- we clear that to make room for synced commands
    collectgarbage()

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

-- Returns true if no reload is necessary, and false otherwise
function LoadProjectCommandWidget:__CheckCorrectEditorAndMap()
    if self.isZip then
        self:__LoadArchive(self.path)
    end

    local sbInfoStr = self:__LoadFile("sb_info.lua")
    local sbInfo = loadstring(sbInfoStr)()
    local game, mapName = sbInfo.game, sbInfo.mapName

	local reload = false
    if game.name ~= Game.gameName then
		Log.Notice("Different game (" .. game.name .. " " .. game.version .. "). Reloading into project...")
        reload = true
	elseif mapName ~= Game.mapName then
		Log.Notice("Different map (" .. mapName .. "). Reloading into project...")
		reload = true
    end
    if reload then
        local modOpts = SB.GetPersistantModOptions()
        local modOptsTxt = ""
        for k, v in pairs(modOpts) do
            modOptsTxt = modOptsTxt .. tostring(k) .. " = " .. tostring(v) .. ";\n"
        end

        -- We make a lowercase copy of the script.txt and parse it
        -- This is necessary as it simplifies searching with case-sensitive tools
        -- However we have to create the new script using the original case..
        -- .. or we risk case sensitive elements (e.g. map name) being broken
        local scriptTxt = self:__LoadFile("script-dev.txt")
        local scriptTxtCpy = scriptTxt:lower()
        local _, endTitle = scriptTxtCpy:find("modoptions")
        if endTitle then
            endTitle = endTitle + 1
            local bracesStart = endTitle + scriptTxtCpy:sub(endTitle):find("{")
            scriptTxt = scriptTxt:sub(1, bracesStart) ..
                        modOptsTxt ..
                        scriptTxt:sub(bracesStart + 1)
        else
            _, endTitle = scriptTxtCpy:find("game")
            if endTitle then
                endTitle = endTitle + 1
                local bracesStart = endTitle + scriptTxtCpy:sub(endTitle):find("{")
                scriptTxt = scriptTxt:sub(1, bracesStart) ..
                            '\n[modoptions]' ..
                            '\n{\n' ..
                            modOptsTxt ..
                            '{\n' ..
                            scriptTxt:sub(bracesStart + 1)
            else
                Log.Warning('Problem parsing script.txt, launching with existing setting.\n' ..
                            'Spring-Launcher may fail to work')
                Log.Warning(scriptTxt)
            end
        end
        Log.Notice('Reloading with start script: ')
        Log.Notice(scriptTxt)
        Spring.Reload(scriptTxt)
	end

    return not reload
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
