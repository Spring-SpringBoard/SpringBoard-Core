SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

HeightmapEditor = Editor:extends{}
Editor.Register({
    name = "heightmapEditor",
    editor = HeightmapEditor,
    tab = "Map",
    caption = "Terrain",
    tooltip = "Edit heightmap",
    image = SB_IMG_DIR .. "peaks.png",
    order = 0,
})

function HeightmapEditor:init()
    self:super("init")

    self:AddField(AssetField({
        name = "patternTexture",
        title = "Pattern:",
        rootDir = "brush_patterns/terrain/",
        expand = true,
        itemWidth = 65,
        itemHeight = 65,
        Validate = function(obj, value)
            if value == nil then
                return true
            end
            if not AssetField.Validate(obj, value) then
                return false
            end

            local ext = Path.GetExt(value) or ""
            return table.ifind(SB_IMG_EXTS, ext), value
        end,
        Update = function(...)
            AssetField.Update(...)
            local texture = self.fields["patternTexture"].value
            SB.model.terrainManager:generateShape(texture)
        end
    }))

    self.btnAddState = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Increase or decrease",
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
        tooltip = "Set the terrain",
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
        tooltip = "Smooth the terrain",
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
    self:AddDefaultKeybinding({
        self.btnAddState,
        self.btnSetState,
        self.btnSmoothState
    })

    self:AddControl("btn-show-metal", {
        Button:New {
            caption = "Show elevation",
            width = 200,
            height = 40,
            OnClick = {
                function()
                    Spring.SendCommands('showelevation')
                end
            }
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
        title = "Rotation:",
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
			y = 70,
			bottom = 30,
			right = 0,
			borderColor = {0,0,0,0},
			horizontalScrollbar = false,
			children = { self.stackPanel },
		},
	}

	self:Finalize(children)
end

function HeightmapEditor:OnLeaveState(state)
    for _, btn in pairs({self.btnAddState, self.btnSmoothState, self.btnSetState}) do
        btn:SetPressedState(false)
    end
end

function HeightmapEditor:OnEnterState(state)
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

function HeightmapEditor:IsValidTest(state)
    return state:is_A(AbstractHeightmapEditingState)
end
