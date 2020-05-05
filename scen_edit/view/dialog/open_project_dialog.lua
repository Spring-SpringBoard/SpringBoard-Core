SB.Include(Path.Join(SB.DIRS.SRC, 'view/dialog/file_dialog.lua'))

OpenProjectDialog = FileDialog:extends {
    dir = SB.DIRS.PROJECTS,
    caption = "Open project"
}

function OpenProjectDialog:ConfirmDialog()
    local path = self:getSelectedFilePath()

    if not Project.IsDirProject(path) then
        self:SetDialogError('Cannot open "' .. tostring(path) .. '" - not a SpringBoard project')
        return false
    end

    if self.confirmDialogCallback then
        return self:__ErrorCheck(self.confirmDialogCallback(path))
    end
end
