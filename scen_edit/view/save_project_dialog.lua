SB.Include(Path.Join(SB_VIEW_DIR, "file_dialog.lua"))

SaveProjectDialog = FileDialog:extends{}

function SaveProjectDialog:init(dir)
    self:super("init", dir, "Save project")
end

function SaveProjectDialog:save(path)
    if self.confirmDialogCallback then
        self.confirmDialogCallback(path)
    end
end

function SaveProjectDialog:confirmDialog()
    local path = self:getSelectedFilePath()
    --TODO: create a dialogue which prompts the user if they want to delete the existing file
    if VFS.FileExists(path, VFS.RAW_ONLY) then
        os.remove(path)
    end
    self:save(path)
end
