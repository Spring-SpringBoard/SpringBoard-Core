SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")
MetalEditorView = MapEditorView:extends{}

function MetalEditorView:init()
    self:super("init")

    self.btnAddMetal = TabbedPanelButton({
        x = 10,
        y = 10,
        tooltip = "Add metal",
        children = {
            TabbedPanelImage({ file = SCEN_EDIT_IMG_DIR .. "terrain_height.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                SCEN_EDIT.stateManager:SetState(MetalEditingState(self))
            end
        },
    })
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
        height = 100,
        x = 0,
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
        maxValue = 5000,
        title = "Size:",
        tooltip = "Size of the paint brush",
    })

    self.window = Window:New {
        parent = screen0,
        x = 50,
        y = 200,
        width = 410,
        height = 300,
        caption = 'Metal editor',
        resizable = true,
        children = {
            ScrollPanel:New {
                x = 0,
                y = "50%",
                bottom = 30,
                right = 0,
                borderColor = {0,0,0,0},
                horizontalScrollbar = false,
                children = { self.stackPanel },
            },
            self.btnAddMetal,
            self.btnClose,
        },
    }
end

function MetalEditorView:IsValidTest(state)
    return state:is_A(TerrainChangeTextureState)
end