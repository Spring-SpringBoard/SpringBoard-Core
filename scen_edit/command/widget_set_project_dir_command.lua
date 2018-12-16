WidgetSetProjectDirCommand = Command:extends{}
WidgetSetProjectDirCommand.className = "WidgetSetProjectDirCommand"

function WidgetSetProjectDirCommand:init(projectDir)
    self.projectDir = projectDir
end

function WidgetSetProjectDirCommand:execute()
    SB.SetProjectDir(self.projectDir)
    SB.conf:initializeListOfMetaModelFiles()
    local reloadMetaModelCommand = ReloadMetaModelCommand(SB.conf:GetMetaModelFiles())
    SB.commandManager:execute(reloadMetaModelCommand)
    SB.commandManager:execute(reloadMetaModelCommand, true)
end
