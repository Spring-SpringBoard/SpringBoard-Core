MetaPanel = AbstractMainWindowPanel:extends{}

function MetaPanel:init()
    self:super("init")
    self:AddElement({
        caption = "Area",
        tooltip = "Edit areas",
        image = SB_IMG_DIR .. "bolivia.png",
        ViewClass = AreasWindow,
        viewName = "areasWindow",
    })
    self:AddElement({
        caption = "Triggers",
        tooltip = "Edit triggers",
        image = SB_IMG_DIR .. "cog.png",
        ViewClass = TriggersWindow,
        viewName = "triggersWindow",
    })
    self:AddElement({
        caption = "Variables",
        tooltip = "Edit variables",
        image = SB_IMG_DIR .. "omega.png",
        ViewClass = VariablesWindow,
        viewName = "variablesWindow",
    })
end
