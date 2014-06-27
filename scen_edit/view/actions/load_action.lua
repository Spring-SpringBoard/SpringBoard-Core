LoadAction = AbstractAction:extends{}

function LoadAction:execute()
    local dir = FilePanel.lastDir or SCEN_EDIT_EXAMPLE_DIR_RAW_FS
    ofd = OpenProjectDialog(dir)					
    ofd:setConfirmDialogCallback(
        function(path)
            local cmd = LoadCommandWidget(path)
            SCEN_EDIT.commandManager:execute(cmd, true)
        end
    )
end
