MetaPanel = AbstractMainWindowPanel:extends{}

function MetaPanel:init()
    self:super("init")
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Add a rectangle area",
        OnClick = {
            function(obj)
                obj:SetPressedState(true)
                if SB.areasWindow == nil then
                    SB.areasWindow = AreasWindow()
                    SB.areasWindow.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
                end
                if SB.areasWindow.window.hidden then
                    SB.view:SetMainPanel(SB.areasWindow.window)
                end
            end
        },
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "bolivia.png" }),
            TabbedPanelLabel({ caption = "Area" }),
        },
    }))
    self.control:AddChild(TabbedPanelButton({
        tooltip = "Trigger settings",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "cog.png" }),
            TabbedPanelLabel({ caption = "Triggers" }),
        },
        OnClick = {
            function(obj)
                obj:SetPressedState(true)
                if SB.triggersWindow == nil then
                    SB.triggersWindow = TriggersWindow()
                    SB.triggersWindow.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
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
            TabbedPanelImage({ file = SB_IMG_DIR .. "omega.png" }),
            TabbedPanelLabel({ caption = "Variables" }),
        },
        OnClick = {
            function(obj)
                obj:SetPressedState(true)
                if SB.variablesWindow == nil then
                    SB.variablesWindow = VariablesWindow()
                    SB.variablesWindow.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
                end
                if SB.variablesWindow.window.hidden then
                    SB.view:SetMainPanel(SB.variablesWindow.window)
                end
            end
        },
    }))
end
