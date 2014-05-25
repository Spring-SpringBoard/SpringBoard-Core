AlliancePanel = AbstractMainWindowPanel:extends{}

function AlliancePanel:init()
	self:super("init")
    local btnDiplomacy = Button:New {
        caption = '',
        height = 80,
        width = 80,
        tooltip = "Alliance settings",
        children = {
            Image:New {                 
                file=SCEN_EDIT_IMG_DIR .. "alliance.png", 
				height = 40, 
				width = 40,
				x = 10,
            },
			Label:New {
				caption = "Alliances",
				y = 40,
				x = 2,
			},
        },
    }
    local btnPlayers = Button:New {
        height = 80,
        width = 80,
        caption = '',
        tooltip = "Player settings",
        children = {
            Image:New {                 
                file=SCEN_EDIT_IMG_DIR .. "players.png", 
				height = 40, 
				width = 40,
                margin = {0, 0, 0, 0},
				x = 10,
            },
			Label:New {
				caption = "Players",
				y = 40,
                x = 6,
			},
        },
    }
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
			height = btnPlayers.height,
			width = btnPlayers.width,
			children = {btnPlayers},
			padding = {0, 0, 0, 0},
			margin = {0, 0, 0, 0},
			itemMargin = {0, 0, 0, 0},
			itemPadding = {0, 0, 0, 0},
		}
	)
	btnDiplomacy.OnClick = {
        function() 
            btnDiplomacy._toggle = DiplomacyWindow()
            btnDiplomacy.parent.disableChildrenHitTest = true
            btnDiplomacy.parent:Invalidate()
            table.insert(btnDiplomacy._toggle.window.OnDispose, 
                function()
                    if btnDiplomacy and btnDiplomacy.parent then
                        btnDiplomacy.parent.disableChildrenHitTest = false
                        btnDiplomacy.parent:Invalidate()
                    end
                end
            )
        end
    }

    btnPlayers.OnClick = {
        function()
            btnPlayers._toggle = PlayersWindow()
            btnPlayers.parent.disableChildrenHitTest = true
            btnPlayers.parent:Invalidate()
            table.insert(btnPlayers._toggle.window.OnDispose, 
                function()
                    if btnPlayers and btnPlayers.parent then
                        btnPlayers.parent.disableChildrenHitTest = false
                        btnPlayers.parent:Invalidate()
                    end
                end
            )
        end
    }
end
