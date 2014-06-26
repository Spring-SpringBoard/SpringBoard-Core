SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

OpenProjectDialog = FileDialog:extends{}

function OpenProjectDialog:init(dir)
    self:super("init", dir, "Open project")
end

function OpenProjectDialog:confirmDialog()
    local path = self:getSelectedFilePath()
    local exists = VFS.FileExists(path, VFS.RAW_ONLY)    
    if exists then
        if self.confirmDialogCallback then 
            self.confirmDialogCallback(path)
        end
    end
end
