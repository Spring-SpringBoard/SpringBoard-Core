GeneralPanel = AbstractMainWindowPanel:extends{}

function GeneralPanel:init()
	self:super("init")
	self.control:AddChild(TabbedPanelButton({
			tooltip = "Scenario info settings",
			OnClick = {
				function(obj)
					obj:SetPressedState(true)
					if SB.scenarioInfoView == nil then
						SB.scenarioInfoView = ScenarioInfoView()
						SB.scenarioInfoView.window.OnHide = {
							function()
								obj:SetPressedState(false)
							end
						}
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
			TabbedPanelImage({ file = SB_IMG_DIR .. "shaking-hands.png" }),
			TabbedPanelLabel({ caption = "Alliances" }),
		},
		OnClick = {
			function(obj)
				obj:SetPressedState(true)
				if SB.diplomacyWindow == nil then
					SB.diplomacyWindow = DiplomacyWindow()
					SB.diplomacyWindow.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
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
			TabbedPanelImage({ file = SB_IMG_DIR .. "person.png" }),
			TabbedPanelLabel({ caption = "Teams"}),
		},
		OnClick = {
			function(obj)
				obj:SetPressedState(true)
				if SB.playersWindow == nil then
					SB.playersWindow = PlayersWindow()
					SB.playersWindow.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
				end
				if SB.playersWindow.window.hidden then
					SB.view:SetMainPanel(SB.playersWindow.window)
				end
			end
		}
	}))
end
