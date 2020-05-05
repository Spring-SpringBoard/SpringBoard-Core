SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/file_dialog.lua'))

OpenFileDialog = FileDialog:extends{
    caption = "Open file"
}

function OpenFileDialog:init(dir)
    self.dir = dir
    FileDialog.init(self)
end

function OpenFileDialog:ConfirmDialog()
    local filePath = self:getSelectedFilePath()
    if not VFS.FileExists(filePath, VFS.RAW_ONLY) then
        self:SetDialogError("Please select a valid file")
        return false
    end

    if self.confirmDialogCallback then
        return self:__ErrorCheck(self.confirmDialogCallback(filePath))
    end
end
