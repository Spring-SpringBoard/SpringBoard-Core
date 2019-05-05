ReloadIntoProjectCommand = Command:extends{}
ReloadIntoProjectCommand.className = "ReloadIntoProjectCommand"

function ReloadIntoProjectCommand:init(path)
    self.path = path
end

function ReloadIntoProjectCommand:execute()
    -- We make a lowercase copy of the script.txt and parse it
    -- This is necessary as it simplifies searching with case-sensitive tools
    -- However we have to create the new script using the original case..
    -- .. or we risk case sensitive elements (e.g. map name) being broken
    local scriptTxt = VFS.LoadFile(Path.Join(self.path, "script-dev.txt"), VFS.RAW)
    local scriptObj = StartScript.ParseStartScript(scriptTxt)
    for k, v in pairs(SB.GetPersistantModOptions()) do
        scriptObj.modOptions[k] = v
    end

    local scriptGame = scriptObj.modOptions._sb_game_name
    local scriptVersion = scriptObj.modOptions._sb_game_version
    if scriptGame == nil then
        Log.Notice('Project saved with older editor.' ..
            ' Please upgrade manually')
        return false
    elseif scriptGame ~= Game.gameName then
        Log.Warning("Trying to open project in incompatible editor: " ..
            "Editor: " .. Game.gameName .. " Project: " .. scriptGame ..
            ". Cannot run in appropriate version")
        return false
    else
        if scriptVersion ~= Game.gameVersion then
            Log.Notice('Opening project saved with different game version: ' ..
                'Editor: ' .. Game.gameVersion .. ' Project: ' .. scriptVersion)
        end
        scriptObj.game = {
            name = Game.gameName,
            version = Game.gameVersion
        }
    end
    scriptObj.modOptions._sb_game_name = nil
    scriptObj.modOptions._sb_game_version = nil
    scriptObj.players = scriptObj.players or {}
    scriptObj.ais = scriptObj.ais or {}

    table.echo(scriptObj)
    scriptTxt = StartScript.GenerateScriptTxt(scriptObj)
    Log.Notice('Reloading with start script: ')
    Log.Notice(scriptTxt)
    Spring.Reload(scriptTxt)

    return false
end

