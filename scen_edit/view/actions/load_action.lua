LoadAction = LCS.class{}

function LoadAction:execute()
    if Spring.GetGameRulesParam("sb_gameMode") ~= "dev" then
        Log.Warning("Cannot load while testing.")
        return
    end

    ofd = OpenProjectDialog(SB_PROJECTS_DIR)
    ofd:setConfirmDialogCallback(
        function(path)
            local cmd = LoadProjectCommandWidget(path)
            SB.commandManager:execute(cmd, true)
        end
    )
end
