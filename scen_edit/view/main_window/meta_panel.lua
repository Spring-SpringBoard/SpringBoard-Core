MetaPanel = AbstractMainWindowPanel:extends{}

function MetaPanel:init()
    self:super("init")
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Add a rectangle area", 
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(AddRectState())
            end
        },
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "view-fullscreen.png" }),
            TabbedPanelLabel({ caption = "Area" }),
        },
    }))
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Trigger settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "applications-system.png" }),
            TabbedPanelLabel({ caption = "Triggers" }),
        },
        OnClick = {
            function ()
                if SCEN_EDIT.triggersWindow == nil then
                    self.triggersWindow = TriggersWindow()
                    SCEN_EDIT.triggersWindow = self.triggersWindow
                end
                if SCEN_EDIT.triggersWindow.window.hidden then
                    SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.triggersWindow.window)
                end
            end
        },
    }))
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Variable settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "format-text-bold.png" }),
            TabbedPanelLabel({ caption = "Variables" }),
        },
        OnClick = {
            function()
                if SCEN_EDIT.variablesWindow == nil then
                    self.variablesWindow = VariableSettingsWindow()
                    SCEN_EDIT.variablesWindow = self.variablesWindow
                end
                if SCEN_EDIT.variablesWindow.window.hidden then
                    SCEN_EDIT.view:SetMainPanel(SCEN_EDIT.variablesWindow.window)
                end
            end
        },
    }))
end
