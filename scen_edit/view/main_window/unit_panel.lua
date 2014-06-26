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
end