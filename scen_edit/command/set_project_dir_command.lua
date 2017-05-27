SetProjectDirCommand = Command:extends{}
SetProjectDirCommand.className = "SetProjectDirCommand"

function SetProjectDirCommand:init(projectDir)
    self.className = "SetProjectDirCommand"
    self.projectDir = projectDir
end

function SetProjectDirCommand:execute()
	SB.projectDir = self.projectDir
end
