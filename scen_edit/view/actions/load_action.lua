LoadAction = AbstractAction:extends{}

function LoadAction:execute()
    local dir = FilePanel.lastDir or SB_PROJECTS_DIR
    ofd = OpenProjectDialog(dir)
    ofd:setConfirmDialogCallback(
        function(path)
            local cmd = LoadCommandWidget(path)
            SCEN_EDIT.commandManager:execute(cmd, true)
        end
    )
end
