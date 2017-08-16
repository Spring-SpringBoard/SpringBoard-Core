ExportAction = LCS.class{}

local EXPORT_SCENARIO_ARCHIVE = "Scenario archive"
local EXPORT_MAP_TEXTURES = "Map textures"
local EXPORT_MAP_INFO = "Map info"
local EXPORT_S11N = "s11n object format"
local fileTypes = {EXPORT_SCENARIO_ARCHIVE, EXPORT_MAP_TEXTURES, EXPORT_MAP_INFO, EXPORT_S11N}

function ExportAction:execute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot export while testing.")
        return
    end

    if SB.projectDir == nil then
        --FIXME: probably don't need for most types of export
        Log.Warning("The project must be saved before exporting")
        return
    end

    sfd = ExportFileDialog(SB_PROJECTS_DIR, fileTypes)
    sfd:setConfirmDialogCallback(
        function(path, fileType)
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

                Log.Notice("Exporting map textures...")
                exportCommand = ExportMapsCommand(path)
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
                Log.Error("Error trying to export. Invalida fileType specified: " .. tostring(fileType))
            end

            if exportCommand then
                SB.commandManager:execute(exportCommand, true)
                Log.Notice("Export complete.")
                return true
            end
        end
    )
end
