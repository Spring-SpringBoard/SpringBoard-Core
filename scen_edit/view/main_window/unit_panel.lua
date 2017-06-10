UnitFeaturePanel = AbstractMainWindowPanel:extends{}

function UnitFeaturePanel:init()
    self:super("init")
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Unit type panel",
            OnClick = {
                function(obj)
    				obj:SetPressedState(true)
                    if SB.unitDefsView == nil then
                        SB.unitDefsView = UnitDefsView()
                        SB.unitDefsView.window.OnHide = {
    						function()
    							obj:SetPressedState(false)
    						end
    					}
                    end
                    if SB.unitDefsView.window.hidden then
                        SB.view:SetMainPanel(SB.unitDefsView.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "meeple.png" }),
                TabbedPanelLabel({ caption = "Units" }),
            },
        })
    )
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Feature type panel",
            OnClick = {
                function(obj)
    				obj:SetPressedState(true)
                    if SB.featureDefsView == nil then
                        SB.featureDefsView = FeatureDefsView()
                        SB.featureDefsView.window.OnHide = {
    						function()
    							obj:SetPressedState(false)
    						end
    					}
                    end
                    if SB.featureDefsView.window.hidden then
                        SB.view:SetMainPanel(SB.featureDefsView.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "beech.png" }),
                TabbedPanelLabel({ caption = "Features" }),
            },
        })
    )
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Edit selected unit property",
            OnClick = {
                function(obj)
    				obj:SetPressedState(true)
                    if SB.objectPropertyWindow == nil then
                        SB.objectPropertyWindow = ObjectPropertyWindow()
                        SB.objectPropertyWindow.window.OnHide = {
    						function()
    							obj:SetPressedState(false)
    						end
    					}
                    end
                    if SB.objectPropertyWindow.window.hidden then
                        SB.view:SetMainPanel(SB.objectPropertyWindow.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "anatomy.png" }),
                TabbedPanelLabel({ caption = "Properties" }),
            },
        })
    )
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Collision volume",
            OnClick = {
                function(obj)
    				obj:SetPressedState(true)
                    if SB.collisionView == nil then
                        SB.collisionView = CollisionView()
                        SB.collisionView.window.OnHide = {
    						function()
    							obj:SetPressedState(false)
    						end
    					}
                    end
                    if SB.collisionView.window.hidden then
                        SB.view:SetMainPanel(SB.collisionView.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "boulder-dash.png" }),
                TabbedPanelLabel({ caption = "Colvol" }),
            },
        })
    )
    -- self.control:AddChild(TabbedPanelButton({
    --         tooltip = "Unit animations",
    --         OnClick = {
    --             function()
    --                 if SB.animationsView == nil then
    --                     SB.animationsView = AnimationsView()
    --                 end
    --                 if SB.animationsView.window.hidden then
    --                     SB.view:SetMainPanel(SB.animationsView.window)
    --                 end
    --             end
    --         },
    --         children = {
    --             TabbedPanelImage({ file = SB_IMG_DIR .. "unit.png" }),
    --             TabbedPanelLabel({ caption = "Anims" }),
    --         },
    --     })
    -- )
end
