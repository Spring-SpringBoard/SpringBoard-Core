SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

OpenFileDialog = FileDialog:extends{}

function OpenFileDialog:init(dir)
    self:super("init", dir, "Open file")
end

function OpenFileDialog:confirmDialog()
    local path = self:getSelectedFilePath()
    local exists = VFS.FileExists(path, VFS.RAW_ONLY)    
    if exists then
        if self.confirmDialogCallback then 
            self.confirmDialogCallback(path)
        end
    end
end
