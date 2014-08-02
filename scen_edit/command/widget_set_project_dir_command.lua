WidgetSetProjectDirCommand = AbstractCommand:extends{}

function WidgetSetProjectDirCommand:init(projectDir)
    self.className = "WidgetSetProjectDirCommand"
    self.projectDir = projectDir
end

function WidgetSetProjectDirCommand:execute()
    SCEN_EDIT.projectDir = self.projectDir
    SCEN_EDIT.conf:initializeListOfMetaModelFiles()
    local reloadMetaModelCommand = ReloadMetaModelCommand(SCEN_EDIT.conf:GetMetaModelFiles())
    SCEN_EDIT.commandManager:execute(reloadMetaModelCommand)
    SCEN_EDIT.commandManager:execute(reloadMetaModelCommand, true)
end
