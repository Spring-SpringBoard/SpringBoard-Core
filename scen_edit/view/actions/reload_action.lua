ReloadAction = LCS.class{}

function ReloadAction:execute()
    SB.conf:initializeListOfMetaModelFiles()
    local command = ReloadMetaModelCommand(SB.conf:GetMetaModelFiles())
    SB.commandManager:execute(command)
    SB.commandManager:execute(command, true)
end
