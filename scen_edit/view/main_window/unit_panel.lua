UnitFeaturePanel = AbstractMainWindowPanel:extends{}

function UnitFeaturePanel:init()
    self:super("init")
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Unit type panel",
            OnClick = {
                function()
                    if SB.unitDefsView == nil then
                        SB.unitDefsView = UnitDefsView()
                    end
                    if SB.unitDefsView.window.hidden then
                        SB.view:SetMainPanel(SB.unitDefsView.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "unit.png" }),
                TabbedPanelLabel({ caption = "Units" }),
            },
        })
    )
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Feature type panel",
            OnClick = {
                function()
                    if SB.featureDefsView == nil then
                        SB.featureDefsView = FeatureDefsView()
                    end
                    if SB.featureDefsView.window.hidden then
                        SB.view:SetMainPanel(SB.featureDefsView.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "feature.png" }),
                TabbedPanelLabel({ caption = "Features" }),
            },
        })
    )
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Edit selected unit property",
            OnClick = {
                function()
                    if SB.objectPropertyWindow == nil then
                        SB.objectPropertyWindow = ObjectPropertyWindow()
                    end
                    if SB.objectPropertyWindow.window.hidden then
                        SB.view:SetMainPanel(SB.objectPropertyWindow.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "feature.png" }),
                TabbedPanelLabel({ caption = "Properties" }),
            },
        })
    )
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Collision volume",
            OnClick = {
                function()
                    if SB.collisionView == nil then
                        SB.collisionView = CollisionView()
                    end
                    if SB.collisionView.window.hidden then
                        SB.view:SetMainPanel(SB.collisionView.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "feature.png" }),
                TabbedPanelLabel({ caption = "Colvol" }),
            },
        })
    )
    self.control:AddChild(TabbedPanelButton({
            tooltip = "Unit animations",
            OnClick = {
                function()
                    if SB.animationsView == nil then
                        SB.animationsView = AnimationsView()
                    end
                    if SB.animationsView.window.hidden then
                        SB.view:SetMainPanel(SB.animationsView.window)
                    end
                end
            },
            children = {
                TabbedPanelImage({ file = SB_IMG_DIR .. "unit.png" }),
                TabbedPanelLabel({ caption = "Anims" }),
            },
        })
    )
end
