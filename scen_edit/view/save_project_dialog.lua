SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

SaveProjectDialog = FileDialog:extends{}

function SaveProjectDialog:init(dir)
    self:super("init", dir, "Save project")
	self.filePanel.showFiles = false
end

function SaveProjectDialog:save(path)
    if self.confirmDialogCallback then 
        self.confirmDialogCallback(path)
    end
end

function SaveProjectDialog:confirmDialog()
    local filePath = self:getSelectedFilePath()
    --TODO: create a dialogue which prompts the user if they want to delete the existing file
    if (VFS.FileExists(filePath)) then
        os.remove(filePath)
    end
    self:save(filePath)
end
