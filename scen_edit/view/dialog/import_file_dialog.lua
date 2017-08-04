SB.Include(Path.Join(SB_VIEW_DIALOG_DIR, "file_dialog.lua"))

ImportFileDialog = FileDialog:extends{}

function ImportFileDialog:init(dir, fileTypes)
    self:super("init", dir, "Import file", fileTypes)
end

function ImportFileDialog:confirmDialog()
    local filePath = self:getSelectedFilePath()
    local fileType = self:getSelectedFileType()

    if not VFS.FileExists(filePath, VFS.RAW_ONLY) then
        return
    end

    if self.confirmDialogCallback then
        return self.confirmDialogCallback(filePath, fileType)
    end
end
