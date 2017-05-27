GeneralPanel = AbstractMainWindowPanel:extends{}

function GeneralPanel:init()
	self:super("init")
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Scenario info settings",
			OnClick = {
				function()
					if SB.scenarioInfoView == nil then
						SB.scenarioInfoView = ScenarioInfoView()
					end
					if SB.scenarioInfoView.window.hidden then
						SB.view:SetMainPanel(SB.scenarioInfoView.window)
					end
				end
			},
			children = {
				TabbedPanelImage({ file = SB_IMG_DIR .. "info.png" }),
				TabbedPanelLabel({ caption = "Info" }),
			},
		})
	)
	self.control:AddChild(TabbedPanelButton({
		tooltip = "Alliance settings",
		children = {
			TabbedPanelImage({ file = SB_IMG_DIR .. "alliance.png" }),
			TabbedPanelLabel({ caption = "Alliances" }),
		},
		OnClick = {
			function()
				if SB.diplomacyWindow == nil then
					SB.diplomacyWindow = DiplomacyWindow()
				end
				if SB.diplomacyWindow.window.hidden then
					SB.view:SetMainPanel(SB.diplomacyWindow.window)
				end
			end
		}
	}))
	self.control:AddChild(TabbedPanelButton({
		tooltip = "Team settings",
		children = {
			TabbedPanelImage({ file = SB_IMG_DIR .. "players.png" }),
			TabbedPanelLabel({ caption = "Teams"}),
		},
		OnClick = {
			function()
				if SB.playersWindow == nil then
					SB.playersWindow = PlayersWindow()
				end
				if SB.playersWindow.window.hidden then
					SB.view:SetMainPanel(SB.playersWindow.window)
				end
			end
		}
	}))
end
