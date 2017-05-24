MetaPanel = AbstractMainWindowPanel:extends{}

function MetaPanel:init()
    self:super("init")
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Add a rectangle area", 
        OnClick = {
            function()
                SB.stateManager:SetState(AddRectState())
            end
        },
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "view-fullscreen.png" }),
            TabbedPanelLabel({ caption = "Area" }),
        },
    }))
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Trigger settings",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "applications-system.png" }),
            TabbedPanelLabel({ caption = "Triggers" }),
        },
        OnClick = {
            function ()
                if SB.triggersWindow == nil then
                    self.triggersWindow = TriggersWindow()
                    SB.triggersWindow = self.triggersWindow
                end
                if SB.triggersWindow.window.hidden then
                    SB.view:SetMainPanel(SB.triggersWindow.window)
                end
            end
        },
    }))
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Variable settings",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "format-text-bold.png" }),
            TabbedPanelLabel({ caption = "Variables" }),
        },
        OnClick = {
            function()
                if SB.variablesWindow == nil then
                    self.variablesWindow = VariableSettingsWindow()
                    SB.variablesWindow = self.variablesWindow
                end
                if SB.variablesWindow.window.hidden then
                    SB.view:SetMainPanel(SB.variablesWindow.window)
                end
            end
        },
    }))
end
