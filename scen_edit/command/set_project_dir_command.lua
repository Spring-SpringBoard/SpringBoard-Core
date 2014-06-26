SetProjectDirCommand = AbstractCommand:extends{}
SetProjectDirCommand.className = "SetProjectDirCommand"

function SetProjectDirCommand:init(projectDir)
    self.className = "SetProjectDirCommand"
    self.projectDir = projectDir
end

function SetProjectDirCommand:execute()
	SCEN_EDIT.model.projectDir = self.projectDir    
end
