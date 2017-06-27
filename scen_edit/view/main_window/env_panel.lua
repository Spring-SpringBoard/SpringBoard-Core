EnvPanel = AbstractMainWindowPanel:extends{}

function EnvPanel:init()
    self:super("init")
    self:AddElement({
        caption = "Water",
        tooltip = "Edit water",
        image = SB_IMG_DIR .. "wave-crest.png",
        ViewClass = WaterEditor,
        viewName = "waterEditor",
    })
    self:AddElement({
        caption = "Lighting",
        tooltip = "Edit lighting",
        image = SB_IMG_DIR .. "sunbeams.png",
        ViewClass = LightingEditor,
        viewName = "lightingEditor",
    })
    self:AddElement({
        caption = "Sky",
        tooltip = "Edit sky and fog",
        image = SB_IMG_DIR .. "night-sky.png",
        ViewClass = SkyEditor,
        viewName = "skyEditor",
    })
end
