ExportAction = AbstractAction:extends{}

function ExportAction:execute()
    if SCEN_EDIT.projectDir ~= nil then
        local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
        local fileTypes = {"Scenario archive", "Feature placer", "Map textures"}
        sfd = ExportFileDialog(dir, fileTypes)
        sfd:setConfirmDialogCallback(
            function(path, fileType)
                if fileType == fileTypes[1] then
                    Spring.Log("scened", LOG.NOTICE, "Exporting archive: " .. path .. " ...")
                    local exportCommand = ExportCommand(path)
                    SCEN_EDIT.commandManager:execute(exportCommand, true)
                    Spring.Log("scened", LOG.NOTICE, "Exported archive.")
                elseif fileType == fileTypes[2] then
                    Spring.Log("scened", LOG.NOTICE, "Exporting to featureplacer format...")
                    local exportCommand = ExportFeaturePlacerCommand(path)
                    SCEN_EDIT.commandManager:execute(exportCommand, true)
                    Spring.Log("scened", LOG.NOTICE, "Export complete.")
                elseif fileType == fileTypes[3] then
                    Spring.Log("scened", LOG.NOTICE, "Exporting map textures...")
                    local exportCommand = ExportMapsCommand(path)
                    SCEN_EDIT.commandManager:execute(exportCommand, true)
                    Spring.Log("scened", LOG.NOTICE, "Export complete.")
                else
                    Spring.Log("scened", LOG.ERROR, "Error trying to export. Invalida fileType specified: " .. tostring(fileType))
                end
            end
        )
    else
        Spring.Log("scened", LOG.WARNING, "The project must be saved before exporting")
    end
end
