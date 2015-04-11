SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")
TerrainEditorView = MapEditorView:extends{}

function TerrainEditorView:init()
    self:super("init")

    self.textureImages = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_textures/",
        width = "100%",
        height = "100%",
        multiSelect = false,
        iconX = 48,
        iconY = 48,
    }
    -- FIXME: implement a button for entering the mode instead of image selection
    self.textureImages.OnSelectItem = {
        function(obj, itemIdx, selected)
            -- FIXME: shouldn't be using ._dirsNum probably
            if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
                local item = self.textureImages.items[itemIdx]
                self.paintTexture = item
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                SCEN_EDIT.commandManager:execute(CacheTextureCommand(self.paintTexture))
                if currentState:is_A(TerrainChangeTextureState) then
                    currentState.paintTexture = item
                else
                    SCEN_EDIT.stateManager:SetState(TerrainChangeTextureState(self))
                end
            end
            -- FIXME: disallow deselection
--             if not selected then
--                 local currentState = SCEN_EDIT.stateManager:GetCurrentState()
--                 SCEN_EDIT.stateManager:SetState(DefaultState())
--             end
        end
    }

    self.detailTextureImages = ImageListView:New {
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/detail/",
        width = "100%",
        height = "100%",
        multiSelect = false,
        iconX = 48,
        iconY = 48,
    }
    self.detailTextureImages.OnSelectItem = {
        function(obj, itemIdx, selected)
            -- FIXME: shouldn't be using ._dirsNum probably
            if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
                local item = self.detailTextureImages.items[itemIdx]
                self.penTexture = item
                SCEN_EDIT.commandManager:execute(CacheTextureCommand(self.penTexture))
                local currentState = SCEN_EDIT.stateManager:GetCurrentState()
                if currentState:is_A(TerrainChangeTextureState) then
                    currentState.penTexture = item
                end
            end
        end
    }
    self.detailTextureImages:Select("spacer.bmp")

    self.tabPanel = Chili.TabPanel:New {
        x = 0, 
        right = 0,
        y = 20, 
        height = "49%",
        padding = {0, 0, 0, 0},
        tabs = { {
                name = "Brush",
                children = {
                    ScrollPanel:New {
                        x = 1,
                        right = 1,
                        y = 15,
                        bottom = 0,
                        children = { 
                            self.textureImages,
                        }
                    },
                },
            }, {
                name = "Detail", 
                children = { 
                    ScrollPanel:New {
                        x = 1,
                        right = 1,
                        y = 15,
                        bottom = 0,
                        children = { 
                            self.detailTextureImages 
                        },
                    },
                },
            }
        },
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
        y = 0,
        height = 400,
        x = 0,
        right = 0,
        centerItems = false,
        itemPadding = {0,0,0,0},
        padding = {0,0,0,0},
        margin = {0,0,0,0},
        itemMargin = {0,0,0,0},
    }

    self:AddChoiceProperty({
        name = "mode",
        items = {
            "Normal",
            "Darken",
            "Lighten",
            "SoftLight",
            "HardLight",
            "Luminance",
            "Multiply",
            "Premultiplied",
            "Overlay",
            "Screen",
            "Add",
            "Subtract",
            "Difference",
            "InverseDifference",
            "Exclusion",
            "Color",
            "ColorBurn",
            "ColorDodge",
        },
        title = "Mode:"
    })
    self:AddNumericProperty({
        name = "size", 
        value = 100, 
        minValue = 10, 
        maxValue = 5000, 
        title = "Size:",
        tooltip = "Size of the paint brush",
    })
    self:AddNumericProperty({
        name = "rotation",
        value = 0,
        minValue = 0,
        maxValue = 360,
        title = "Texture rotation:",
        tooltip = "Rotation of the texture",
    })
    self:AddNumericProperty({
        name = "texScale",
        value = 2,
        minValue = 0.1,
        maxValue = 50,
        title = "Texture scale:",
        tooltip = "Texture sampling rate (larger number means higher frequency)",
    })
    self:AddNumericProperty({
        name = "texOffsetX",
        value = 0,
        minValue = -1024,
        maxValue = 1024,
        title = "Texture offset X:",
        tooltip = "Texture offset X",
    })
    self:AddNumericProperty({
        name = "texOffsetY",
        value = 0,
        minValue = -1024,
        maxValue = 1024,
        title = "Texture offset Y:",
        tooltip = "Texture offset Y",
    })
    self:AddNumericProperty({
        name = "detailTexScale",
        value = 0.2,
        minValue = 0.01,
        maxValue = 1,
        title = "Detail texture scale:",
        tooltip = "Detail texture sampling rate (larger number means higher frequency)",
    })
    self:AddNumericProperty({
        name = "blendFactor",
        value = 1,
        minValue = 0.0,
        maxValue = 1,
        title = "Blend factor:",
        tooltip = "Proportion of texture to be applied",
    })
    self:AddNumericProperty({
        name = "falloffFactor",
        value = 0.3,
        minValue = 0.0,
        maxValue = 1,
        title = "Falloff factor:",
        tooltip = "Texture painting fade out (1 means crisp)",
    })
    self:AddNumericProperty({
        name = "featureFactor",
        value = 1,
        minValue = 0.0,
        maxValue = 1,
        title = "Feature factor:",
        tooltip = "Feature filtering (1 means no filter filtering)",
    })
    self:AddColorbarsProperty({
        name = "diffuseColor",
        title = "Color: ",
        value = {1,1,1,1},
    })
    self:UpdateNumericField("size")
    self:UpdateChoiceField("mode")
    self:UpdateColorbarsField("diffuseColor")

    self.window = Window:New {
        parent = screen0,
        x = 50,
        y = 200,
        width = 410,
        height = 600,
        caption = 'Texture editor',
        resizable = true,
        children = {
            self.tabPanel,
            ScrollPanel:New {
                x = 0,
                y = "50%",
                bottom = 30,
                right = 0,
                borderColor = {0,0,0,0},
                horizontalScrollbar = false,
                children = { self.stackPanel },
            },
            self.btnClose,
        },
    }
end

function TerrainEditorView:Select(indx)
    self.textureImages:Select(indx)
end

function TerrainEditorView:IsValidTest(state)
    return state:is_A(TerrainChangeTextureState)
end