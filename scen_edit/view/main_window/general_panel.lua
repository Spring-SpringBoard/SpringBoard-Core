GeneralPanel = AbstractMainWindowPanel:extends{}

function GeneralPanel:init()
	self:super("init")
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Save project (Ctrl+S)",
			OnClick = {
				function()
                    SaveAction():execute()
				end
			},
			children = {
				TabbedPanelImage({ file = SB_IMG_DIR .. "document-save.png" }),
				TabbedPanelLabel({ caption = "Save" }),
			},
		})
	)
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Save project as... (Ctrl+Shift+S)",
			OnClick = {
				function()
                    SaveAsAction():execute()
				end
			},
			children = {
				TabbedPanelImage({ file = SB_IMG_DIR .. "document-save.png" }),
				TabbedPanelLabel({ caption = "Save as" }),
			},
		})
	)
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Load project (Ctrl-O)",
			OnClick = {
				function()
                    LoadAction():execute()
				end
			},
			children = {
				TabbedPanelImage({ file = SB_IMG_DIR .. "document-open.png" }),
				TabbedPanelLabel({ caption = "Load" }),
			},
		})
	)
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Scenario info settings",
			OnClick = {
				function()
					local scenarioInfoView = ScenarioInfoView()
				end
			},
			children = {
				TabbedPanelImage({ file = SB_IMG_DIR .. "info.png" }),
				TabbedPanelLabel({ caption = "Info" }),
			},
		})
	)
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Export to (Ctrl-E)...",
			OnClick = {
				function()
                    ExportAction():execute()
				end
			},
			children = {
				TabbedPanelImage({ file = SB_IMG_DIR .. "document-save.png" }),
				TabbedPanelLabel({ caption = "Export" }),
			},
		})
	)
    self.control:AddChild(TabbedPanelButton({
			tooltip = "Import from (Ctrl-I)...",
			OnClick = {
				function()
                    ImportAction():execute()
				end
			},
			children = {
				TabbedPanelImage({ file = SB_IMG_DIR .. "document-open.png" }),
				TabbedPanelLabel({ caption = "Import" }),
			},
		})
	)
end
