ExportAction = AbstractAction:extends{}

function ExportAction:execute()
    if SB.projectDir ~= nil then
        local fileTypes = {"Scenario archive", "Feature placer", "Map textures", "Map info"}
        sfd = ExportFileDialog(SB_PROJECTS_DIR, fileTypes)
        sfd:setConfirmDialogCallback(
            function(path, fileType)
                local exportCommand
                if fileType == fileTypes[1] then
                    Log.Notice("Exporting archive: " .. path .. " ...")
                    exportCommand = ExportCommand(path)
                elseif fileType == fileTypes[2] then
                    Log.Notice("Exporting to featureplacer format...")
                    exportCommand = ExportFeaturePlacerCommand(path)
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
    else
        --FIXME: probably don't need for most types of export
        Log.Warning("The project must be saved before exporting")
    end
end
