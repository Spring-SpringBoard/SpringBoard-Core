FileDialog = Observable:extends{}

local function ExtractFileName(filepath)
  filepath = filepath:gsub("\\", "/")
  local lastChar = filepath:sub(-1)
  if (lastChar == "/") then
    filepath = filepath:sub(1,-2)
  end
  local pos,b,e,match,init,n = 1,1,1,1,0,0
  repeat
    pos,init,n = b,init+1,n+1
    b,init,match = filepath:find("/",init,true)
  until (not b)
  if (n==1) then
    return filepath
  else
    return filepath:sub(pos+1)
  end
end

function FileDialog:init(dir, caption)
    self.dir = dir or nil
	self.caption = caption or "File dialog"
    self.confirmDialogCallback = nil
    local buttonPanel = MakeComponentPanel()
    self.fileEditBox = EditBox:New {
        y = 1,
		x = 75,
		right = 0,
        height = "100%",
    }
    
    local okButton = Button:New {
        height = SCEN_EDIT.conf.B_HEIGHT,
        bottom = 5,
        width = "20%",
        right = "22%",
        caption = "OK",
    }
    
    local cancelButton = Button:New {
        height = SCEN_EDIT.conf.B_HEIGHT,
        bottom = 5,
        width = "20%",
		right = 10,
        caption = "Cancel",
    }
    self.filePanel = FilePanel:New {
        x = 10,
        y = 10,
        width = "100%",
        height = "100%",            
        dir = self.dir,
        multiselect = false,
    }
    self.filePanel.OnSelectItem = {
        function (obj, itemIdx, selected) 
            if selected and itemIdx > self.filePanel._dirsNum+1 then
                local fullPath = tostring(obj.items[itemIdx])
                local fileName = ExtractFileName(fullPath)
                self.fileEditBox:SetText(fileName)
            end
        end
    }                
    
    self.window = Window:New {
        x = 500,
        y = 200,
        width = 600,
        height = 600,
        parent = screen0,
        caption = self.caption,
        children = {
            ScrollPanel:New {
                width = "100%",
                y = 10,
                bottom = 80,
                children = {
                    self.filePanel,
                },
            },
            Control:New {
                x = 1,
                width = "100%",
                height = SCEN_EDIT.conf.B_HEIGHT,
                bottom = SCEN_EDIT.conf.B_HEIGHT + 20,
                padding = {0, 0, 0, 0},
                children = {                
                    Label:New {
						x = 1,
						y = 4,
						valign = "center",						
                        width = 65,
                        caption = "File name: ",
						align = "left",
                    },                
                    self.fileEditBox,
                },
            },
            okButton,
            cancelButton,            
        },
    }
    okButton.OnClick = {
        function()
            self:confirmDialog()
            self.window:Dispose()
        end
    }
    cancelButton.OnClick = {
        function()
            self.window:Dispose()
        end
    }
--    self:SetDir(self.dir)
end

function FileDialog:setConfirmDialogCallback(func)
    self.confirmDialogCallback = func
end

function FileDialog:getSelectedFilePath()
    local path = self.filePanel.dir .. self.fileEditBox.text
    return path
end

function FileDialog:confirmDialog()
    local path = self:getSelectedFilePath()
    if self.confirmDialogCallback then
        self.confirmDialogCallback(path)
    end
end
