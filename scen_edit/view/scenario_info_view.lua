ScenarioInfoView = LCS.class{}

function ScenarioInfoView:init()
	self.lblName = Label:New {
		caption = "Name:",
		x = 1,
		width = 80,
	}
	self.ebName = EditBox:New {
		text = SCEN_EDIT.model.scenarioInfo.name,
		right = 1,
		width = 300,
	}
	
	self.lblDescription = Label:New {
		caption = "Description:",
		x = 1,
		width = 80,
		y = 30,
	}
	self.ebDescription = EditBox:New {
		text = SCEN_EDIT.model.scenarioInfo.description,
		right = 1,
		width = 300,
		y = 30,
	}
	
	self.lblVersion = Label:New {
		caption = "Version:",
		x = 1,
		width = 80,
		y = 60,
	}
	self.ebVersion = EditBox:New {
		text = tostring(SCEN_EDIT.model.scenarioInfo.version),
		right = 1,
		width = 300,
		y = 60,
	}
	
	self.lblAuthor = Label:New {
		caption = "Author:",
		x = 1,
		width = 80,
		y = 90,
	}
	self.ebAuthor = EditBox:New {
		text = SCEN_EDIT.model.scenarioInfo.author,
		right = 1,
		width = 300,
		y = 90,
	}
	
	self.btnOK = Button:New {
		caption = "OK",
		y = 140,
		x = 40,
		width = 120,
		height = SCEN_EDIT.conf.B_HEIGHT,
	}
	
	self.btnCancel = Button:New {
		caption = "Cancel",
		y = 140,
		right = 40,
		width = 120,
		height = SCEN_EDIT.conf.B_HEIGHT,
	}
	
	self.window = Window:New {
		x = 800,
		y = 300,
		width = 450,
		height = 200,
		children = {
			self.lblName,
			self.ebName,
			self.lblDescription,
			self.ebDescription,
			self.lblVersion,
			self.ebVersion,
			self.lblAuthor,
			self.ebAuthor,
			self.btnOK,
			self.btnCancel,
		},
		parent = screen0,
	}
	
	self.btnOK.OnClick = { 
		function() 
			self:confirm() 
			self.window:Dispose()
		end
	}
	self.btnCancel.OnClick = { 
		function() 
			self.window:Dispose() 
		end 
	}
end

function ScenarioInfoView:confirm()
	SCEN_EDIT.model.scenarioInfo.name = self.ebName.text
	SCEN_EDIT.model.scenarioInfo.description = self.ebDescription.text
	SCEN_EDIT.model.scenarioInfo.version = self.ebVersion.text
	SCEN_EDIT.model.scenarioInfo.author = self.ebAuthor.text
end