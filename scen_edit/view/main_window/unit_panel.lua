UnitFeaturePanel = AbstractMainWindowPanel:extends{}

function UnitFeaturePanel:init()
	self:super("init")
	self.control:AddChild(Button:New {
			height = 80,
			width = 80,
			caption = '',
			tooltip = "Unit type panel",
			OnClick = {
				function()
					self.unitDefsView = UnitDefsView()
				end
			},
			children = {
				Image:New {                                
					file = SCEN_EDIT_IMG_DIR .. "unit.png",
					height = 40, 
					width = 40,
					margin = {0, 0, 0, 0},
					x = 10,
				},
				Label:New {
					caption = "Units",
					y = 40,
					x = 14,
				},
			},
		}
	)
	self.control:AddChild(Button:New {
			height = 80,
			width = 80,
			caption = '',
			tooltip = "Feature type panel",
			OnClick = {
				function()
					self.featureDefsView = FeatureDefsView()
				end
			},
			children = {
				Image:New {                                
					file = SCEN_EDIT_IMG_DIR .. "feature.png",
					height = 40, 
					width = 40,
					margin = {0, 0, 0, 0},
					x = 10,
				},
				Label:New {
					caption = "Features",
					y = 40,
				},
			},
		}
	)
end