SB.Include(Path.Join(SB_VIEW_DIALOG_DIR, "file_dialog.lua"))

OpenFileDialog = FileDialog:extends{}

function OpenFileDialog:init(dir)
    self:super("init", dir, "Open file")
end

function OpenFileDialog:ConfirmDialog()
    local filePath = self:getSelectedFilePath()
    if not VFS.FileExists(filePath, VFS.RAW_ONLY) then
        return
    end

    if self.confirmDialogCallback then
        return self.confirmDialogCallback(filePath)
    end
end
