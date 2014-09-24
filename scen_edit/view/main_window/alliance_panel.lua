AlliancePanel = AbstractMainWindowPanel:extends{}

function AlliancePanel:init()
	self:super("init")
    local btnDiplomacy = TabbedPanelButton({
        tooltip = "Alliance settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "alliance.png" }),
			TabbedPanelLabel({ caption = "Alliances" }),
        },
    })
    local btnTeams = TabbedPanelButton({
        tooltip = "Team settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "players.png" }),
			TabbedPanelLabel({ caption = "Teams"}),
        },
    })
	self.control:AddChild(Chili.LayoutPanel:New {
			height = btnDiplomacy.height,
			width = btnDiplomacy.width,
			children = {btnDiplomacy},
			padding = {0, 0, 0, 0},
			margin = {0, 0, 0, 0},
			itemMargin = {0, 0, 0, 0},
			itemPadding = {0, 0, 0, 0},
		}
	)
	self.control:AddChild(Chili.LayoutPanel:New {
			height = btnTeams.height,
			width = btnTeams.width,
			children = {btnTeams},
			padding = {0, 0, 0, 0},
			margin = {0, 0, 0, 0},
			itemMargin = {0, 0, 0, 0},
			itemPadding = {0, 0, 0, 0},
		}
	)
	btnDiplomacy.OnClick = {
        function() 
            btnDiplomacy._toggle = DiplomacyWindow()
            SCEN_EDIT.SetControlEnabled(btnDiplomacy.parent, false) 
            table.insert(btnDiplomacy._toggle.window.OnDispose, 
                function()
                    if btnDiplomacy and btnDiplomacy.parent then
                        SCEN_EDIT.SetControlEnabled(btnDiplomacy.parent, true) 
                    end
                end
            )
        end
    }

    btnTeams.OnClick = {
        function()
            btnTeams._toggle = PlayersWindow()
            SCEN_EDIT.SetControlEnabled(btnTeams.parent, false) 
            table.insert(btnTeams._toggle.window.OnDispose, 
                function()
                    if btnTeams and btnTeams.parent then
                        SCEN_EDIT.SetControlEnabled(btnTeams.parent, true) 
                    end
                end
            )
        end
    }
end
