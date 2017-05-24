SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

OpenProjectDialog = FileDialog:extends{}

function OpenProjectDialog:init(dir)
    self:super("init", dir, "Open project")
end

function OpenProjectDialog:confirmDialog()
    local path = self:getSelectedFilePath()

    if not self:DirIsProject(path) then
        return
    end

    if self.confirmDialogCallback then
        self.confirmDialogCallback(path)
    end
end

-- Checks whether directory is a SpringBoard project
-- FIXME: This could probably be moved somewhere else
function OpenProjectDialog:DirIsProject(path)
    if not (VFS.FileExists(path, VFS.RAW_ONLY) or
            SCEN_EDIT.DirExists(path, VFS.RAW_ONLY)) then
        return false
    end

    local modelExists = VFS.FileExists(Path.Join(path, "model.lua"),
        VFS.RAW)
    local heightMapExists = VFS.FileExists(Path.Join(path, "heightmap.data"),
        VFS.RAW)

    return modelExists and heightMapExists
end
