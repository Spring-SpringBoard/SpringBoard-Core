TerrainPanel = AbstractMainWindowPanel:extends{}

function TerrainPanel:init()
    self:super("init")
    local btnModifyHeightMap = TabbedPanelButton({
        tooltip = "Modify heightmap",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "peaks.png" }),
            TabbedPanelLabel({ caption = "Terrain" }),
        },
        OnClick = {
            function(obj)
                obj:SetPressedState(true)
                if SB.heightmapEditorView == nil then
                    SB.heightmapEditorView = HeightmapEditorView()
                    SB.heightmapEditorView.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
                end
                if SB.heightmapEditorView.window.hidden then
					SB.view:SetMainPanel(SB.heightmapEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyHeightMap)

    local btnModifyTextureMap = TabbedPanelButton({
        tooltip = "Change texture",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "palette.png" }),
            TabbedPanelLabel({ caption = "Texture" }),
        },
        OnClick = {
            function(obj)
                obj:SetPressedState(true)
                if SB.terrainEditorView == nil then
                    SB.terrainEditorView = TerrainEditorView()
                    SB.terrainEditorView.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
                end
                if SB.terrainEditorView.window.hidden then
					SB.view:SetMainPanel(SB.terrainEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyTextureMap)

    local btnModifyGrass = TabbedPanelButton({
        tooltip = "Change grass map",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "grass.png" }),
            TabbedPanelLabel({ caption = "Grass" }),
        },
        OnClick = {
            function(obj)
                obj:SetPressedState(true)
                if SB.grassEditorView == nil then
                    SB.grassEditorView = GrassEditorView()
                    SB.grassEditorView.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
                end
                if SB.grassEditorView.window.hidden then
					SB.view:SetMainPanel(SB.grassEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyGrass)

    local btnModifyMetal = TabbedPanelButton({
        tooltip = "Change metal map",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "minerals.png" }),
            TabbedPanelLabel({ caption = "Metal" }),
        },
        OnClick = {
            function(obj)
                obj:SetPressedState(true)
                if SB.metalEditorView == nil then
                    SB.metalEditorView = MetalEditorView()
                    SB.metalEditorView.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
                end
                if SB.metalEditorView.window.hidden then
					SB.view:SetMainPanel(SB.metalEditorView.window)
                end
            end
        },
    })
    self.control:AddChild(btnModifyMetal)

	local btnTerrainSettings = TabbedPanelButton({
        tooltip = "Change map settings",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "globe.png" }),
            TabbedPanelLabel({ caption = "Settings" }),
        },
        OnClick = {
            function(obj)
                obj:SetPressedState(true)
                if SB.terrainSettingsView == nil then
                    SB.terrainSettingsView = TerrainSettingsView()
                    SB.terrainSettingsView.window.OnHide = {
						function()
							obj:SetPressedState(false)
						end
					}
                end
                if SB.terrainSettingsView.window.hidden then
					SB.view:SetMainPanel(SB.terrainSettingsView.window)
                end
            end
        },
    })
    self.control:AddChild(btnTerrainSettings)
end
