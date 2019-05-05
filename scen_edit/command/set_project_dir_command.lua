SetProjectNamePathCommand = Command:extends{}
SetProjectNamePathCommand.className = "SetProjectNamePathCommand"

function SetProjectNamePathCommand:init(name, path)
    self.name = name
    self.path = path
end

function SetProjectNamePathCommand:execute()
    if SB.project.name ~= nil then
        for i = 1, #SB.project.mutators do
            local mutator = SB.project.mutators[i]
            if String.Starts(mutator, SB.project.name) then
                SB.project.mutators[i] = self.name .. ' 1.0'
            end
        end
    end

    SB.project.name = self.name
    SB.project:SetPath(self.path)
end


WidgetSetProjectDirCommand = Command:extends{}
WidgetSetProjectDirCommand.className = "WidgetSetProjectDirCommand"

function WidgetSetProjectDirCommand:init(projectDir)
    self.projectDir = projectDir
end

function WidgetSetProjectDirCommand:execute()
    SB.project:SetPath(self.projectDir)
    SB.conf:initializeListOfMetaModelFiles()
    local reloadMetaModelCommand = ReloadMetaModelCommand(SB.conf:GetMetaModelFiles())
    SB.commandManager:execute(reloadMetaModelCommand)
    SB.commandManager:execute(reloadMetaModelCommand, true)
end
