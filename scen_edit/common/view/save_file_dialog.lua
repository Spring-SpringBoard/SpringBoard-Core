local SCEN_EDIT_COMMON_DIR = "scen_edit/common/"
local SCEN_EDIT_VIEW_DIR = SCEN_EDIT_COMMON_DIR .. "view/"
VFS.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

SaveFileDialog = FileDialog:extends{}