UnitFeaturePanel = AbstractMainWindowPanel:extends{}

function UnitFeaturePanel:init()
	self:super("init")
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Unit type panel",
			OnClick = {
				function()
					self.unitDefsView = UnitDefsView()
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "unit.png" }),
				TabbedPanelLabel({ caption = "Units" }),
			},
		})
	)
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Feature type panel",
			OnClick = {
				function()
					self.featureDefsView = FeatureDefsView()
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "feature.png" }),
				TabbedPanelLabel({ caption = "Features" }),
			},
		})
	)
    self.control:AddChild(TabbedPanelButton({
			tooltip = "Edit selected unit property",
			OnClick = {
				function()
                    self.objectPropertyWindow = UnitPropertyWindow()
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "feature.png" }),
				TabbedPanelLabel({ caption = "Properties" }),
			},
		})
	)
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Collision volume",
			OnClick = {
				function()
                    self.collisionView = CollisionView()
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "feature.png" }),
				TabbedPanelLabel({ caption = "Colvol" }),
			},
		})
	)
end