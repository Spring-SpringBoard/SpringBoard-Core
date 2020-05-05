SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/file_dialog.lua'))

ImportFileDialog = FileDialog:extends {
    caption = "Import"
}

function ImportFileDialog:init(dir, fileTypes)
    self.dir = dir
    self.fileTypes = fileTypes
    FileDialog.init(self)
end

function ImportFileDialog:ConfirmDialog()
    local filePath = self:getSelectedFilePath()

    if not VFS.FileExists(filePath, VFS.RAW_FIRST) then
        self:SetDialogError('"' .. tostring(filePath) .. '" is not a  file.')
        return false
    end

    if self.confirmDialogCallback then
        return self:__ErrorCheck(
            self.confirmDialogCallback(filePath, self.fields.fileType.value)
        )
    end
end
