UnitFeaturePanel = AbstractMainWindowPanel:extends{}

function UnitFeaturePanel:init()
	self:super("init")
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Unit type panel",
			OnClick = {
				function()
                    if SCEN_EDIT.unitDefsView == nil then
                        self.unitDefsView = UnitDefsView()
                        SCEN_EDIT.unitDefsView = self.unitDefsView
                    end
                    if SCEN_EDIT.unitDefsView.window.hidden then
                        SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.unitDefsView.window)
                    end
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
                    if SCEN_EDIT.featureDefsView == nil then
                        self.featureDefsView = FeatureDefsView()
                        SCEN_EDIT.featureDefsView = self.featureDefsView
                    end
                    if SCEN_EDIT.featureDefsView.window.hidden then
                        SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.featureDefsView.window)
                    end
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
                    if SCEN_EDIT.unitPropertyWindow == nil then
                        self.unitPropertyWindow = UnitPropertyWindow()
                        SCEN_EDIT.unitPropertyWindow = self.unitPropertyWindow
                    end
                    if SCEN_EDIT.unitPropertyWindow.window.hidden then
                        SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.unitPropertyWindow.window)
                    end
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
                    if SCEN_EDIT.collisionView == nil then
                        self.collisionView = CollisionView()
                        SCEN_EDIT.collisionView = self.collisionView
                    end
                    if SCEN_EDIT.collisionView.window.hidden then
                        SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.collisionView.window)
                    end
				end
			},
			children = {
				TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "feature.png" }),
				TabbedPanelLabel({ caption = "Colvol" }),
			},
		})
	)
end