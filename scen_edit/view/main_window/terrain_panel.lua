TerrainPanel = AbstractMainWindowPanel:extends{}

function TerrainPanel:init()
    self:super("init")
    self:AddElement({
        caption = "Terrain",
        tooltip = "Edit heightmap",
        image = SB_IMG_DIR .. "peaks.png",
        ViewClass = HeightmapEditorView,
        viewName = "heightmapEditorView",
    })
    self:AddElement({
        caption = "Texture",
        tooltip = "Edit textures",
        image = SB_IMG_DIR .. "palette.png",
        ViewClass = TerrainEditorView,
        viewName = "terrainEditorView",
    })
    self:AddElement({
        caption = "Grass",
        tooltip = "Edit grass",
        image = SB_IMG_DIR .. "grass.png",
        ViewClass = GrassEditorView,
        viewName = "grassEditorView",
    })
    self:AddElement({
        caption = "Metal",
        tooltip = "Edit metal map",
        image = SB_IMG_DIR .. "minerals.png",
        ViewClass = MetalEditorView,
        viewName = "metalEditorView",
    })
    self:AddElement({
        caption = "Settings",
        tooltip = "Edit map settings",
        image = SB_IMG_DIR .. "globe.png",
        ViewClass = TerrainSettingsView,
        viewName = "terrainSettingsView",
    })
end
