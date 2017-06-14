SB.Include(Path.Join(SB_VIEW_DIR, "file_dialog.lua"))

OpenFileDialog = FileDialog:extends{}

function OpenFileDialog:init(dir)
    self:super("init", dir, "Open file")
end

function OpenFileDialog:confirmDialog()
    local path = self:getSelectedFilePath()
    Spring.Echo(path)
    if not VFS.FileExists(path, VFS.RAW_ONLY) then
        return
    end

    if self.confirmDialogCallback then
        self.confirmDialogCallback(path)
    end
end
