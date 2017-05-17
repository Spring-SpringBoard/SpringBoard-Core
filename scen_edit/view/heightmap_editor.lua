SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "editor_view.lua")
HeightmapEditorView = EditorView:extends{}

function HeightmapEditorView:init()
    self:super("init")

    self.heightmapBrushes = TextureBrowser({
		rootDir = "brush_patterns/terrain/",
        width = "100%",
        height = "100%",
    })
    -- FIXME: implement a button for entering the mode instead of image selection
    self.heightmapBrushes.control.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                local item = self.heightmapBrushes.control.children[itemIdx]
                if item.texture ~= nil then
                    self.paintTexture = item.texture.diffuse
                    SCEN_EDIT.model.terrainManager:generateShape(self.paintTexture)
                    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                    if currentState:is_A(AbstractHeightmapEditingState) then
                        currentState.paintTexture = self.paintTexture
                    end
                end
            end
        end
    }

    self.btnAddState = TabbedPanelButton({
        x = 0,
        y = 0,
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

    self.btnSetState = TabbedPanelButton({
        x = 70,
        y = 0,
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

    self.btnSmoothState = TabbedPanelButton({
        x = 140,
        y = 0,
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

    self:AddField(NumericField({
        name = "size",
        value = 100,
        minValue = 10,
        maxValue = 1000,
        title = "Size:",
        tooltip = "Size of the height brush",
    }))
    self:AddField(NumericField({
        name = "rotation",
        value = 0,
        minValue = -360,
        maxValue = 360,
        title = "Shape rotation:",
        tooltip = "Rotation of the shape",
    }))
    self:AddField(NumericField({
        name = "strength",
        value = 10,
        step = 0.1,
        title = "Strength:",
        tooltip = "Strength of the height map tool",
    }))
    self:AddField(NumericField({
        name = "height",
        value = 10,
        step = 0.1,
        title = "Height:",
        tooltip = "Goal height",
    }))
    self:Update("size")

    local children = {
		self.btnAddState,
        self.btnSetState,
		self.btnSmoothState,
		ScrollPanel:New {
			x = 0,
			right = 0,
			y = 70,
			height = "35%",
			children = {
				self.heightmapBrushes.control,
			}
		},
		ScrollPanel:New {
			x = 0,
			y = "45%",
			bottom = 30,
			right = 0,
			borderColor = {0,0,0,0},
			horizontalScrollbar = false,
			children = { self.stackPanel },
		},
	}

	self:Finalize(children)
-- 	self.heightmapBrushes:Select("circle.png")
end

function HeightmapEditorView:StoppedEditing()
    self.btnAddState.state.pressed = false
    self.btnAddState:Invalidate()

    self.btnSmoothState.state.pressed = false
    self.btnSmoothState:Invalidate()

    self.btnSetState.state.pressed = false
    self.btnSetState:Invalidate()

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
--         elseif currentState:is_A(TerrainChangeHeightRectState) then
--             btn = self.btnChangeHeightRectState
        elseif currentState:is_A(TerrainSetState) then
            btn = self.btnSetState
        elseif currentState:is_A(TerrainSmoothState) then
            btn = self.btnSmoothState
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
