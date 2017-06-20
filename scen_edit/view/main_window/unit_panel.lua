UnitFeaturePanel = AbstractMainWindowPanel:extends{}

function UnitFeaturePanel:init()
    self:super("init")
    self:AddElement({
        caption = "Units",
        tooltip = "Add units",
        image = SB_IMG_DIR .. "meeple.png",
        ViewClass = UnitDefsView,
        viewName = "unitDefsView",
    })
    self:AddElement({
        caption = "Features",
        tooltip = "Add features",
        image = SB_IMG_DIR .. "beech.png",
        ViewClass = FeatureDefsView,
        viewName = "featureDefsView",
    })
    self:AddElement({
        caption = "Properties",
        tooltip = "Edit object properties",
        image = SB_IMG_DIR .. "anatomy.png",
        ViewClass = ObjectPropertyWindow,
        viewName = "objectPropertyWindow",
    })
    self:AddElement({
        caption = "Colvol",
        tooltip = "Edit collision volumes",
        image = SB_IMG_DIR .. "boulder-dash.png",
        ViewClass = CollisionView,
        viewName = "collisionView",
    })
    -- self:AddElement({
    --     caption = "Anims",
    --     tooltip = "Unit animations",
    --     image = SB_IMG_DIR .. "meeple.png",
    --     ViewClass = AnimationsView,
    --     viewName = "animationsView",
    -- })
end
