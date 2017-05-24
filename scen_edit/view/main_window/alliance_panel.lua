AlliancePanel = AbstractMainWindowPanel:extends{}

function AlliancePanel:init()
    self:super("init")
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Alliance settings",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "alliance.png" }),
            TabbedPanelLabel({ caption = "Alliances" }),
        },
        OnClick = {
            function() 
                if SB.diplomacyWindow == nil then
                    self.diplomacyWindow = DiplomacyWindow()
                    SB.diplomacyWindow = self.diplomacyWindow
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
                    self.playersWindow = PlayersWindow()
                    SB.playersWindow = self.playersWindow
                end
                if SB.playersWindow.window.hidden then
                    SB.view:SetMainPanel(SB.playersWindow.window)
                end
            end
        }
    }))
end
