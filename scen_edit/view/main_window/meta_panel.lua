MetaPanel = AbstractMainWindowPanel:extends{}

function MetaPanel:init()
	self:super("init")
    local btnTriggers = TabbedPanelButton({
        tooltip = "Trigger settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "applications-system.png" }),
			TabbedPanelLabel({ caption = "Triggers" }),
        },
    })
    local btnVariableSettings = TabbedPanelButton({
        tooltip = "Variable settings",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "format-text-bold.png" }),
			TabbedPanelLabel({ caption = "Variables" }),
        },
    })

	self.control:AddChild(
		TabbedPanelButton({
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
		})
	)	
	self.control:AddChild(Chili.LayoutPanel:New {
			height = btnTriggers.height,
			width = btnTriggers.width,
			children = {btnTriggers},
			padding = {0, 0, 0, 0},
			margin = {0, 0, 0, 0},
			itemMargin = {0, 0, 0, 0},
			itemPadding = {0, 0, 0, 0},
		}
	)
	self.control:AddChild(Chili.LayoutPanel:New {
			height = btnVariableSettings.height,
			width = btnVariableSettings.width,
			children = {btnVariableSettings},
			padding = {0, 0, 0, 0},
			margin = {0, 0, 0, 0},
			itemMargin = {0, 0, 0, 0},
			itemPadding = {0, 0, 0, 0},
		}
	)
	btnTriggers.OnClick = {
        function () 
            btnTriggers._toggle = TriggersWindow()
            SCEN_EDIT.SetControlEnabled(btnTriggers.parent, false) 
            table.insert(btnTriggers._toggle.window.OnDispose, 
                function()
                    if btnTriggers and btnTriggers.parent then
                        SCEN_EDIT.SetControlEnabled(btnTriggers.parent, true) 
                    end
                end
            )
        end
    }

    btnVariableSettings.OnClick = {
        function()
            btnVariableSettings._toggle = VariableSettingsWindow()
            SCEN_EDIT.SetControlEnabled(btnVariableSettings.parent, false) 
            table.insert(btnVariableSettings._toggle.window.OnDispose, 
                function()
                    if btnVariableSettings and btnVariableSettings.parent then
                        SCEN_EDIT.SetControlEnabled(btnVariableSettings.parent, true) 
                    end
                end
            )
        end
    }
end
