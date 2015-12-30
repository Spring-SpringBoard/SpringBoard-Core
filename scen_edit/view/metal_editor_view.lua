SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "editor_view.lua")
MetalEditorView = EditorView:extends{}

function MetalEditorView:init()
    self:super("init")

    self.btnAddMetal = TabbedPanelButton({
        x = 0,
        y = 0,
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

    self:AddField(NumericField({
        name = "size",
        value = 100,
        minValue = 10,
        maxValue = 5000,
        title = "Size:",
        tooltip = "Size of the paint brush",
    }))

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 80,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
        self.btnAddMetal,
    }
    self:Finalize(children)
end

function MetalEditorView:IsValidTest(state)
    return state:is_A(TerrainChangeTextureState)
end