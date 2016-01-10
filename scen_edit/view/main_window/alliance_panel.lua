AlliancePanel = AbstractMainWindowPanel:extends{}

function AlliancePanel:init()
    self:super("init")
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Alliance settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "alliance.png" }),
            TabbedPanelLabel({ caption = "Alliances" }),
        },
        OnClick = {
            function() 
                if SCEN_EDIT.diplomacyWindow == nil then
                    self.diplomacyWindow = DiplomacyWindow()
                    SCEN_EDIT.diplomacyWindow = self.diplomacyWindow
                end
                if SCEN_EDIT.diplomacyWindow.window.hidden then
                    SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.diplomacyWindow.window)
                end
            end
        }
    }))
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Team settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "players.png" }),
            TabbedPanelLabel({ caption = "Teams"}),
        },
        OnClick = {
            function() 
                if SCEN_EDIT.playersWindow == nil then
                    self.playersWindow = PlayersWindow()
                    SCEN_EDIT.playersWindow = self.playersWindow
                end
                if SCEN_EDIT.playersWindow.window.hidden then
                    SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.playersWindow.window)
                end
            end
        }
    }))
end
