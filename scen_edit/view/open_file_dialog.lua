SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

OpenFileDialog = FileDialog:extends{}

function OpenFileDialog:confirmDialog()
	local path = self:getSelectedFilePath()
	local exists = VFS.FileExists(path)	
	if exists then
		if self.confirmDialogCallback then 
			self.confirmDialogCallback(path)
		end
	end
end
