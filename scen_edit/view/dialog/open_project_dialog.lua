SB.Include(Path.Join(SB_VIEW_DIALOG_DIR, "file_dialog.lua"))

OpenProjectDialog = FileDialog:extends{}

function OpenProjectDialog:init(dir)
    self:super("init", dir, "Open project")
end

function OpenProjectDialog:confirmDialog()
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
