SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/file_dialog.lua'))

OpenProjectDialog = FileDialog:extends {
    dir = SB.DIRS.PROJECTS,
    caption = "Open project"
}

function OpenProjectDialog:ConfirmDialog()
    local path = self:getSelectedFilePath()

    if not Project.IsDirProject(path) then
        return
    end

    if self.confirmDialogCallback then
        self.confirmDialogCallback(path)
        return true
    end
    return false
end
