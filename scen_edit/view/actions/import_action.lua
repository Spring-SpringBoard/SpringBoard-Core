ImportAction = AbstractAction:extends{}

function ImportAction:execute()
    local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
    local fileTypes = {"Feature placer", "Diffuse", "Heightmap"}
    sfd = ImportFileDialog(dir, fileTypes)
    sfd:setConfirmDialogCallback(
        function(path, fileType)
            if fileType == fileTypes[1] then
                Spring.Log("scened", LOG.NOTICE, "Importing feature placer file: " .. path .. " ...")
                local modelData = VFS.LoadFile(path, VFS.RAWFIRST)
                local importCommand = ImportFeaturePlacerCommand(modelData)
                SCEN_EDIT.commandManager:execute(importCommand)
                Spring.Log("scened", LOG.NOTICE, "Import complete.")
            elseif fileType == fileTypes[2] then
                Spring.Log("scened", LOG.NOTICE, "Importing diffuse: " .. path .. " ...")
                local importCommand = ImportDiffuseCommand(path)
                SCEN_EDIT.commandManager:execute(importCommand, true)
                Spring.Log("scened", LOG.NOTICE, "Import complete.")
            else
                Spring.Log("scened", LOG.ERROR, "Error trying to export. Invalida fileType specified: " .. tostring(fileType))
            end
        end
    )
end
