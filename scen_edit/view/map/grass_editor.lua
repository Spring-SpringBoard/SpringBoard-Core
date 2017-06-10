SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

GrassEditorView = EditorView:extends{}

function GrassEditorView:init()
    self:super("init")

    self.btnAddGrass = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Paint grass on the map",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "grass-add.png" }),
            TabbedPanelLabel({ caption = "Paint" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(GrassEditingState(self))
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
        self.btnAddGrass,
        ScrollPanel:New {
            x = 0,
            y = 80,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }
    self:Finalize(children)
end

function GrassEditorView:IsValidTest(state)
    return state:is_A(GrassEditingState)
end

function GrassEditorView:OnLeaveState(state)
    for _, btn in pairs({self.btnAddGrass}) do
        btn:SetPressedState(false)
    end
end

function GrassEditorView:OnEnterState(state)
    self.btnAddGrass:SetPressedState(true)
end
