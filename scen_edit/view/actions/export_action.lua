ExportAction = AbstractAction:extends{}

function ExportAction:execute()
    if SCEN_EDIT.model:GetProjectDir() ~= nil then
        local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
        sfd = ExportFileDialog(dir)
        sfd:setConfirmDialogCallback(
            function(path)
                Spring.Echo("Exporting archive: " .. path .. " ...")
                local exportCommand = ExportCommand(path)
                SCEN_EDIT.commandManager:execute(exportCommand, true)
                Spring.Echo("Exported archive.")
            end
        )
    else
        Spring.Echo("The project must be saved before exporting")
    end
end
