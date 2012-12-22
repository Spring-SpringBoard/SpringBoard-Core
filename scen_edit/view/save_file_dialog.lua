SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "file_dialog.lua")

SaveFileDialog = FileDialog:extends{}

local function explode(div,str)
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

function SaveFileDialog:confirmDialog()
	local fileName = self:getSelectedFilePath()
    --TODO: include the actual path
    fileName = explode('/', fileName)
    fileName = fileName[#fileName]
    fileName = explode('\\', fileName)
    fileName = fileName[#fileName]

    Spring.Echo(fileName)
    local saveCommand = SaveCommand(fileName)
    SCEN_EDIT.commandManager:execute(saveCommand, true)
end
