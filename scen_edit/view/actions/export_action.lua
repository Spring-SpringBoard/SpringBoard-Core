ExportAction = AbstractAction:extends{}

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

    local fileTypes = {"Scenario archive", "Feature placer", "Map textures", "Map info"}
    sfd = ExportFileDialog(SB_PROJECTS_DIR, fileTypes)
    sfd:setConfirmDialogCallback(
        function(path, fileType)
            local exportCommand
            if fileType == fileTypes[1] then
                Log.Notice("Exporting archive: " .. path .. " ...")
                exportCommand = ExportCommand(path)
            elseif fileType == fileTypes[3] then
                Log.Notice("Exporting map textures...")
                exportCommand = ExportMapsCommand(path)
            elseif fileType == fileTypes[4] then
                Log.Notice("Exporting map info...")
                exportCommand = ExportMapInfoCommand(path)
            else
                Log.Error("Error trying to export. Invalida fileType specified: " .. tostring(fileType))
            end
            if exportCommand then
                SB.commandManager:execute(exportCommand, true)
                Log.Notice("Export complete.")
            end
        end
    )
end
