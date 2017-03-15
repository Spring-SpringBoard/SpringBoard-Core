ExportAction = AbstractAction:extends{}

function ExportAction:execute()
    if SCEN_EDIT.projectDir ~= nil then
        local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
        local fileTypes = {"Scenario archive", "Feature placer", "Map textures"}
        sfd = ExportFileDialog(dir, fileTypes)
        sfd:setConfirmDialogCallback(
            function(path, fileType)
                if fileType == fileTypes[1] then
                    Log.Notice("Exporting archive: " .. path .. " ...")
                    local exportCommand = ExportCommand(path)
                    SCEN_EDIT.commandManager:execute(exportCommand, true)
                    Log.Notice("Exported archive.")
                elseif fileType == fileTypes[2] then
                    Log.Notice("Exporting to featureplacer format...")
                    local exportCommand = ExportFeaturePlacerCommand(path)
                    SCEN_EDIT.commandManager:execute(exportCommand, true)
                    Log.Notice("Export complete.")
                elseif fileType == fileTypes[3] then
                    Log.Notice("Exporting map textures...")
                    local exportCommand = ExportMapsCommand(path)
                    SCEN_EDIT.commandManager:execute(exportCommand, true)
                    Log.Notice("Export complete.")
                else
                    Log.Error("Error trying to export. Invalida fileType specified: " .. tostring(fileType))
                end
            end
        )
    else
        --FIXME: probably don't need for most types of export
        Log.Warning("The project must be saved before exporting")
    end
end
