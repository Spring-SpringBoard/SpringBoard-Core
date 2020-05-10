SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/file_dialog.lua'))

SaveProjectDialog = FileDialog:extends {
    dir = SB.DIRS.PROJECTS,
    caption = "Save project",
    openProjectsAsFiles = true
}

function SaveProjectDialog:ConfirmDialog()
    local path = self:getSelectedFilePath()

    if self.fields.fileName.value == "" then
        self:SetDialogError("Missing project name")
        return false
    end

    --TODO: create a dialogue which prompts the user if they want to delete the existing file
    -- if VFS.FileExists(path, VFS.RAW) then
    --     os.remove(path)
    -- end

    if self.confirmDialogCallback then
        return self:__ErrorCheck(self.confirmDialogCallback(path))
    end
end
