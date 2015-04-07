SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")
HeightmapEditorView = MapEditorView:extends{}

function HeightmapEditorView:init()
    self:super("init")

    self.heightmapBrushes = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/height",
        width = "100%",
        height = "100%",
        multiSelect = false,
        iconX = 48,
        iconY = 48,
    }
    -- FIXME: implement a button for entering the mode instead of image selection
    self.heightmapBrushes.OnSelectItem = {
        function(obj, itemIdx, selected)
            -- FIXME: shouldn't be using ._dirsNum probably
            if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
                local item = self.heightmapBrushes.items[itemIdx]
                self.paintTexture = item
                SCEN_EDIT.model.terrainManager:generateShape(self.paintTexture)
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainShapeModifyState) then
                    currentState.paintTexture = item
                end
            end
        end
    }
    self.heightmapBrushes:Select("circle.png")

    self.btnAddState = TabbedPanelButton({
        x = 10,
        y = 10,
        tooltip = "Increase or decrease (1)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainShapeModifyState(self))
            end
        },
    })
    self.btnSmoothState = TabbedPanelButton({
        x = 80,
        y = 10,
        tooltip = "Smooth the terrain (2)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Smooth" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainSmoothState(self))
            end
        },
    })
    self.btnLevelState = TabbedPanelButton({
        x = 150,
        y = 10,
        tooltip = "Level the terrain (3)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Level" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainLevelState(self))
            end
        },
    })

    self.btnSetState = TabbedPanelButton({
        x = 220,
        y = 10,
        tooltip = "Set the terrain (4)",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Set" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(TerrainSetState(self))
            end
        },
    })
--     self.btnChangeHeightRectState = TabbedPanelButton({
--         x = 220,
--         y = 10,
--         tooltip = "Square add the terrain (4)",
--         children = {
--             TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
--             TabbedPanelLabel({ caption = "Square" }),
--         },
--         OnClick = {
--             function()
--                 SCEN_EDIT.stateManager:SetState(TerrainChangeHeightRectState(self))
--             end
--         },
--     })
--     self.btnAddShapeState = TabbedPanelButton({
--         x = 290,
--         y = 10,
--         tooltip = "Modify the terrain by choosing one of the special shapes below (5)",
--         children = {
--             TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
--             TabbedPanelLabel({ caption = "Shape" }),
--         },
--         OnClick = {
--             function()
--                 SCEN_EDIT.stateManager:SetState(TerrainShapeModifyState(self))
--             end
--         },
--     })

    self.imgPanel = ScrollPanel:New {
        x = 0,
        right = 0,
        bottom = 30,
        y = "35%",
        children = {
            self.heightmapBrushes,
        }
    }

    self.btnClose = Button:New {
        caption = 'Close',
        width = 100,
        right = 15,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = {
            function()
                self.window:Hide()
                SCEN_EDIT.stateManager:SetState(DefaultState())
            end 
        },
    }

    self.stackPanel = StackPanel:New {
        height = 90,
        y = 100,
        x = 10,
        right = 0,
        centerItems = false,
        itemPadding = {0,0,0,0},
        padding = {0,0,0,0},
        margin = {0,0,0,0},
        itemMargin = {0,0,0,0},
    }

    self:AddNumericProperty({
        name = "size", 
        value = 100, 
        minValue = 10,
        maxValue = 1000,
        title = "Size:",
        tooltip = "Size of the height brush",
    })
    self:AddNumericProperty({
        name = "rotation",
        value = 0,
        minValue = 0,
        maxValue = 360,
        title = "Shape rotation:",
        tooltip = "Rotation of the shape",
    })
    self:AddNumericProperty({
        name = "strength",
        value = 10,
        minValue = 0.1,
        maxValue = 1000,
        title = "Strength:",
        tooltip = "Strength of the height map tool",
    })
    self:UpdateNumericField("size")

    self.window = Window:New {
        parent = screen0,
        x = 150,
        y = 210,
        width = 410,
        height = 600,
        caption = 'Heightmap editor',
        resizable = true,
        children = {
            self.imgPanel,
            ScrollPanel:New {
                x = 0,
                y = 0,
                bottom = "66%",
                right = 0,
                borderColor = {0,0,0,0},
                horizontalScrollbar = false,
                children = { 
                    self.btnAddState,
                    self.btnSmoothState,
                    self.btnLevelState,
                    self.btnSetState,
--                     self.btnChangeHeightRectState,
--                     self.btnAddShapeState,
                    self.stackPanel 
                },
            },
            self.btnClose,
        },
        OnDispose = { function() SCEN_EDIT.heightmapEditorView = nil end },
    }
    self.heightmapBrushes:Hide()
end

function HeightmapEditorView:StoppedEditing()
    self.btnAddState.state.pressed = false
    self.btnAddState:Invalidate()

    self.btnSmoothState.state.pressed = false
    self.btnSmoothState:Invalidate()

    self.btnLevelState.state.pressed = false
    self.btnLevelState:Invalidate()

    self.btnSetState.state.pressed = false
    self.btnSetState:Invalidate()

    if self.heightmapBrushes.visible then
        self.heightmapBrushes:Hide()
    end
--     self.btnChangeHeightRectState.state.pressed = false
--     self.btnChangeHeightRectState:Invalidate()
-- 
--     self.btnAddShapeState.state.pressed = false
--     self.btnAddShapeState:Invalidate()
end

function HeightmapEditorView:StartedEditing()
    SCEN_EDIT.delay(function()
        local currentState = SCEN_EDIT.stateManager:GetCurrentState()
        local btn
        if currentState:is_A(TerrainShapeModifyState) then
            btn = self.btnAddState
            if self.heightmapBrushes.hidden then
                self.heightmapBrushes:Show()
            end
--         elseif currentState:is_A(TerrainChangeHeightRectState) then
--             btn = self.btnChangeHeightRectState
        elseif currentState:is_A(TerrainSmoothState) then
            btn = self.btnSmoothState
        elseif currentState:is_A(TerrainLevelState) then
            btn = self.btnLevelState
        elseif currentState:is_A(TerrainSetState) then
            btn = self.btnSetState
--         elseif currentState:is_A(TerrainShapeModifyState) then
--             btn = self.btnAddShapeState
        end
        btn.state.pressed = true
        btn:Invalidate()
    end)
end

function HeightmapEditorView:Select(indx)
    self.heightmapBrushes:Select(indx)
end

function HeightmapEditorView:IsValidTest(state)
    return state:is_A(AbstractHeightmapEditingState)
end