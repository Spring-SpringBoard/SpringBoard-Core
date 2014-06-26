SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

ExportFileDialog = FileDialog:extends{}

function ExportFileDialog:init(dir)
    self:super("init", dir, "Export file")
	self.filePanel.showFiles = false
end

function ExportFileDialog:save(path)
    if self.confirmDialogCallback then 
        self.confirmDialogCallback(path)
    end
end

function ExportFileDialog:confirmDialog()
    local filePath = self:getSelectedFilePath()
    --TODO: create a dialog which prompts the user if they want to delete the existing file
    if (VFS.FileExists(filePath)) then
        os.remove(filePath)
    end
    self:save(filePath)
end
