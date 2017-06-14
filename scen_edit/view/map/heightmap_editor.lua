SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

HeightmapEditorView = EditorView:extends{}

function HeightmapEditorView:init()
    self:super("init")

    self.heightmapBrushes = AssetView({
        ctrl = {
			x = 0,
			right = 0,
			y = 70,
            bottom = "55%", -- 100 - 45
        },
        rootDir = "brush_patterns/terrain/",
        OnSelectItem = {
            function(item, selected)
                self.paintTexture = item.path
                if selected and item.isFile then
                    SB.model.terrainManager:generateShape(self.paintTexture)
                    local currentState = SB.stateManager:GetCurrentState()
                    if currentState:is_A(AbstractHeightmapEditingState) then
                        currentState.paintTexture = self.paintTexture
                    end
                end
            end
        }
    })

    self.btnAddState = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Increase or decrease (1)",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "up-card.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(TerrainShapeModifyState(self))
            end
        },
    })

    self.btnSetState = TabbedPanelButton({
        x = 70,
        y = 0,
        tooltip = "Set the terrain (2)",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "terrain-set.png" }),
            TabbedPanelLabel({ caption = "Set" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(TerrainSetState(self))
            end
        },
    })

    self.btnSmoothState = TabbedPanelButton({
        x = 140,
        y = 0,
        tooltip = "Smooth the terrain (3)",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "terrain-smooth.png" }),
            TabbedPanelLabel({ caption = "Smooth" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(TerrainSmoothState(self))
            end
        },
    })

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
        self.heightmapBrushes:GetControl(),
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
end

function HeightmapEditorView:OnLeaveState(state)
    for _, btn in pairs({self.btnAddState, self.btnSmoothState, self.btnSetState}) do
        btn:SetPressedState(false)
    end
end

function HeightmapEditorView:OnEnterState(state)
    local btn
    if state:is_A(TerrainShapeModifyState) then
        btn = self.btnAddState
    elseif state:is_A(TerrainSetState) then
        btn = self.btnSetState
    elseif state:is_A(TerrainSmoothState) then
        btn = self.btnSmoothState
    end
    btn:SetPressedState(true)
end

function HeightmapEditorView:Select(indx)
    self.heightmapBrushes:Select(indx)
end

function HeightmapEditorView:IsValidTest(state)
    return state:is_A(AbstractHeightmapEditingState)
end
