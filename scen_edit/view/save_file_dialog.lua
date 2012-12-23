SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

SaveFileDialog = FileDialog:extends{}

function SaveFileDialog:init(dir)
    self:super("init", dir)
end


function SaveFileDialog:confirmDialog()
	local fileName = self:getSelectedFilePath()
    local saveCommand = SaveCommand(fileName)
    SCEN_EDIT.commandManager:execute(saveCommand, true)
end
