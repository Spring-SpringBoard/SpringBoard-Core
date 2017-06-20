EnvPanel = AbstractMainWindowPanel:extends{}

function EnvPanel:init()
    self:super("init")
    self:AddElement({
        caption = "Water",
        tooltip = "Edit water",
        image = SB_IMG_DIR .. "wave-crest.png",
        ViewClass = WaterEditorView,
        viewName = "waterEditorView",
    })
    self:AddElement({
        caption = "Lighting",
        tooltip = "Edit lighting",
        image = SB_IMG_DIR .. "sunbeams.png",
        ViewClass = LightingEditorView,
        viewName = "lightingEditorView",
    })
    self:AddElement({
        caption = "Sky",
        tooltip = "Edit sky and fog",
        image = SB_IMG_DIR .. "night-sky.png",
        ViewClass = SkyEditorView,
        viewName = "skyEditorView",
    })
end
