LoadAction = AbstractAction:extends{}

function LoadAction:execute()
    ofd = OpenProjectDialog(SB_PROJECTS_DIR)
    ofd:setConfirmDialogCallback(
        function(path)
            local cmd = LoadProjectCommandWidget(path)
            SB.commandManager:execute(cmd, true)
        end
    )
end
