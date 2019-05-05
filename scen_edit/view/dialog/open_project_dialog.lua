SB.Include(Path.Join(SB_VIEW_DIALOG_DIR, "file_dialog.lua"))

OpenProjectDialog = FileDialog:extends {
    dir = SB_PROJECTS_DIR,
    caption = "Open project"
}

function OpenProjectDialog:ConfirmDialog()
    local path = self:getSelectedFilePath()

    if not SB.DirIsProject(path) then
        return
    end

    if self.confirmDialogCallback then
        self.confirmDialogCallback(path)
        return true
    end
    return false
end
