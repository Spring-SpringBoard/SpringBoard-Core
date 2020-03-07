SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/file_dialog.lua'))

SaveProjectDialog = FileDialog:extends {
    dir = SB.DIRS.PROJECTS,
    caption = "Save project"
}

function SaveProjectDialog:ConfirmDialog()
    local path = self:getSelectedFilePath()

    if self.fields.fileName.value == "" then
        return false
    end

    --TODO: create a dialogue which prompts the user if they want to delete the existing file
    -- if VFS.FileExists(path, VFS.RAW_ONLY) then
    --     os.remove(path)
    -- end

    if self.confirmDialogCallback then
        return self.confirmDialogCallback(path)
    end
end
