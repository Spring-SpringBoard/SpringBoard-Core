local Chili = WG.Chili

FileDialog = Observable:extends{}

function FileDialog:init(dir)
    self.dir = dir or ''
	self.confirmDialogCallback = nil
  --[[  self.panel = Chili.LayoutPanel:New {
        autosize = true,

        autoArrangeH = false,
        autoArrangeV = false,
        centerItems  = false,

        iconX     = 64,
        iconY     = 64,

        itemMargin    = {1, 1, 1, 1},

        selectable  = true,
        multiSelect = true,

        items = {},
    }-]]
	local buttonPanel = MakeComponentPanel()
	self.fileEditBox = Chili.EditBox:New {
		width = "40%",
		x = "30%",
		y = 1,
		height = "100%",
	}
	
	local okButton = Chili.Button:New {
		height = SCEN_EDIT.model.B_HEIGHT,
		bottom = 5,
		width = "20%",
		x = "10",
		caption = "OK",
	}
	
	local cancelButton = Chili.Button:New {
		height = SCEN_EDIT.model.B_HEIGHT,
		bottom = 5,
		width = "20%",
		x = "22%",
		caption = "Cancel",
	}
	
    self.window = Chili.Window:New {
        x = 500,
        y = 200,
        width = 600,
        height = 600,
        parent = Chili.Screen0,
        caption = "File dialog",
        children = {
            Chili.ScrollPanel:New {
                width = "100%",
                y = 10,
				bottom = 80,
                children = {
					FilePanel:New {
					    x = 10,
                        y = 10,
						width = "100%",
						height = "100%",	        
						dir = self.dir,
						multiselect = false,
						OnSelectItem = {
							function (obj, itemIdx, selected) 
								if selected then
									self.fileEditBox:SetText(tostring(obj.items[itemIdx]))
								end
							end
						},						
					}
                },
			},
			Chili.StackPanel:New {
				x = 1,
				width = "100%",
				height = SCEN_EDIT.model.B_HEIGHT,
				bottom = SCEN_EDIT.model.B_HEIGHT + 5 + 5,
				padding = {0, 0, 0, 0},
				itemMarging = {0, 0, 0, 0},
				resizeItems = false,
				orientation = "horizontal",
				children = {				
					Chili.Label:New {
						width = "5%",
						x = 1,
						caption = "File name: ",
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
	local path = self.fileEditBox.text
	return path
end

function FileDialog:confirmDialog()
	local path = self:getSelectedFilePath()
	if self.confirmDialogCallback then
		self.confirmDialogCallback(path)
	end
end