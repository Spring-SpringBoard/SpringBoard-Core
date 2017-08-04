SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

MetalEditor = Editor:extends{}
Editor.Register({
    name = "metalEditor",
    editor = MetalEditor,
    tab = "Map",
    caption = "Metal",
    tooltip = "Edit metal map",
    image = SB_IMG_DIR .. "minerals.png",
    order = 3,
})

function MetalEditor:init()
    self:super("init")

    self.btnAddMetal = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Add metal",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "metal-add.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(MetalEditingState(self))
            end
        },
    })
    self:AddDefaultKeybinding({
        self.btnAddMetal
    })

    self:AddField(NumericField({
        name = "size",
        value = 100,
        minValue = 10,
        maxValue = 200,
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

function MetalEditor:IsValidTest(state)
    return state:is_A(MetalEditingState)
end

function MetalEditor:OnLeaveState(state)
    for _, btn in pairs({self.btnAddMetal}) do
        btn:SetPressedState(false)
    end
end

function MetalEditor:OnEnterState(state)
    self.btnAddMetal:SetPressedState(true)
end
