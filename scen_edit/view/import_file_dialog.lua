SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

ImportFileDialog = FileDialog:extends{}

function ImportFileDialog:init(dir, fileTypes)
    self:super("init", dir, "Import file", fileTypes)
end

function ImportFileDialog:confirmDialog()
    local filePath = self:getSelectedFilePath()
    local fileType = self:getSelectedFileType()
    if self.confirmDialogCallback then 
        self.confirmDialogCallback(filePath, fileType)
    end
end
