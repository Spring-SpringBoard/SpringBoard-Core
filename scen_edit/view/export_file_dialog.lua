SB.Include(Path.Join(SB_VIEW_DIR, "file_dialog.lua"))

ExportFileDialog = FileDialog:extends{}

function ExportFileDialog:init(dir, fileTypes)
    self:super("init", dir, "Export file", fileTypes)
	self.filePanel.showFiles = false
end

function ExportFileDialog:confirmDialog()
    local filePath = self:getSelectedFilePath()
    --TODO: create a dialog which prompts the user if they want to delete the existing file
    -- TODO: need to add/check extension first
--     if (VFS.FileExists(filePath)) then
--         os.remove(filePath)
--     end
    local fileType = self:getSelectedFileType()
    if self.confirmDialogCallback then
        self.confirmDialogCallback(filePath, fileType)
    end
end
