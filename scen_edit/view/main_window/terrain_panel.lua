TerrainPanel = AbstractMainWindowPanel:extends{}

function TerrainPanel:init()
    self:super("init")
    self:AddElement({
        caption = "Terrain",
        tooltip = "Edit heightmap",
        image = SB_IMG_DIR .. "peaks.png",
        ViewClass = HeightmapEditor,
        viewName = "heightmapEditor",
    })
    self:AddElement({
        caption = "Texture",
        tooltip = "Edit textures",
        image = SB_IMG_DIR .. "palette.png",
        ViewClass = TerrainEditor,
        viewName = "terrainEditor",
    })
    self:AddElement({
        caption = "Grass",
        tooltip = "Edit grass",
        image = SB_IMG_DIR .. "grass.png",
        ViewClass = GrassEditor,
        viewName = "grassEditor",
    })
    self:AddElement({
        caption = "Metal",
        tooltip = "Edit metal map",
        image = SB_IMG_DIR .. "minerals.png",
        ViewClass = MetalEditor,
        viewName = "metalEditor",
    })
    self:AddElement({
        caption = "Settings",
        tooltip = "Edit map settings",
        image = SB_IMG_DIR .. "globe.png",
        ViewClass = TerrainSettingsView,
        viewName = "terrainSettingsView",
    })
end
