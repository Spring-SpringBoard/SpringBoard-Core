SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

ExportAction = Action:extends{}

ExportAction:Register({
    name = "sb_export",
    tooltip = "Export",
    image = SB_IMG_DIR .. "save.png",
    toolbar_order = 6,
    hotkey = {
        key = KEYSYMS.E,
        ctrl = true
    }
})

local EXPORT_SCENARIO_ARCHIVE = "Scenario archive"
local EXPORT_MAP_TEXTURES = "Map textures"
local EXPORT_MAP_INFO = "Map info"
local EXPORT_S11N = "s11n object format"
local fileTypes = {EXPORT_SCENARIO_ARCHIVE, EXPORT_MAP_TEXTURES, EXPORT_MAP_INFO, EXPORT_S11N}

function ExportAction:canExecute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot export while testing.")
        return false
    end
    if SB.project.path == nil then
        -- FIXME: this should probably be relaxed for most types of export
        Log.Warning("The project must be saved before exporting")
        return false
    end
    return true
end

function ExportAction:execute()
    local sfd = ExportFileDialog(SB_EXPORTS_DIR, fileTypes)
    sfd:setConfirmDialogCallback(
        function(path, fileType, heightmapExtremes)
            local baseName = Path.ExtractFileName(path)
            local isFile = VFS.FileExists(path, VFS.RAW_ONLY)
            local isDir = SB.DirExists(path, VFS.RAW_ONLY)

            if baseName == "" then
                return
            end
            local exportCommand
            if fileType == EXPORT_SCENARIO_ARCHIVE then
                if isDir then
                    return false
                end

                Log.Notice("Exporting archive: " .. path .. " ...")
                exportCommand = ExportCommand(path)
            elseif fileType == EXPORT_MAP_TEXTURES then
                if isFile then
                    return false
                end

                self:MaybeExportMapTextures(path, heightmapExtremes)
                return true
            elseif fileType == EXPORT_MAP_INFO then
                if isDir then
                    return false
                end

                Log.Notice("Exporting map info...")
                exportCommand = ExportMapInfoCommand(path)
            elseif fileType == EXPORT_S11N then
                if isDir then
                    return false
                end

                Log.Notice("Exporting s11n objects...")
                exportCommand = ExportS11NCommand(path)
            else
                Log.Error("Error trying to export. Invalid fileType specified: " .. tostring(fileType))
            end

            if exportCommand then
                SB.commandManager:execute(exportCommand, true)
                Log.Notice("Export complete.")
                return true
            end
        end
    )
end

function ExportAction:MaybeExportMapTextures(path, heightmapExtremes)
    -- At least 2x the necessary amount? Super arbitrary...
    local wantedTexMemPoolSize = Game.mapSizeX / 1024 * Game.mapSizeZ / 1024 * 3 * 4
    local texMemPoolSize = Spring.GetConfigInt("TextureMemPoolSize", 0)
    if wantedTexMemPoolSize > texMemPoolSize then
        Dialog({
            message = "Texture pool size (" .. tostring(texMemPoolSize) ..
                       ") is too small to save the diffuse texture." ..
                      "\nDo you want to increase the pool size (to " ..
                      tostring(wantedTexMemPoolSize) .. ")?",
            ConfirmDialog = function()
                Spring.SetConfigInt("TextureMemPoolSize", wantedTexMemPoolSize)
                SB.AskToRestart()
            end,
        })
        return
    end

    self:ExportMapTextures(path, heightmapExtremes)
end

function ExportAction:ExportMapTextures(path, heightmapExtremes)
    Log.Notice("Exporting map textures...")
    SB.commandManager:execute(ExportMapsCommand(path, heightmapExtremes), true)
end