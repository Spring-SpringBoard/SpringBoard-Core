SB.Include(Path.Join(SB_VIEW_DIALOG_DIR, "file_dialog.lua"))

SaveProjectDialog = FileDialog:extends{}

function SaveProjectDialog:init(dir)
    self:super("init", dir, "Save project")
end

function SaveProjectDialog:confirmDialog()
    local path = self:getSelectedFilePath()
    --TODO: create a dialogue which prompts the user if they want to delete the existing file
    if VFS.FileExists(path, VFS.RAW_ONLY) then
        os.remove(path)
    end

    if self.confirmDialogCallback then
        return self.confirmDialogCallback(path)
    end
end
