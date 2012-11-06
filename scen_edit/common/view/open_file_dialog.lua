local SCEN_EDIT_COMMON_DIR = "scen_edit/common/"
local SCEN_EDIT_VIEW_DIR = SCEN_EDIT_COMMON_DIR .. "view/"
VFS.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

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