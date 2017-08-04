SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

GrassEditor = Editor:extends{}
Editor.Register({
    name = "grassEditor",
    editor = GrassEditor,
    tab = "Map",
    caption = "Grass",
    tooltip = "Edit grass",
    image = SB_IMG_DIR .. "grass.png",
    order = 4,
})

function GrassEditor:init()
    self:super("init")

    self.btnAddGrass = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Add grass to the map",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "grass-add.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(GrassEditingState(self))
            end
        },
    })
    self:AddDefaultKeybinding({
        self.btnAddGrass
    })

    self:AddField(NumericField({
        name = "grassDetail",
        value = Spring.GetConfigInt("GrassDetail"),
        minValue = 0,
        maxValue = 10000,
        step = 0.1,
        title = "Detail:",
        tooltip = "`GrassDetail` engine parameter: controls how much grass is visible." ..
            "This is unsynced and will not be saved.",
    }))

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

function GrassEditor:OnFieldChange(name, value)
    if name == "grassDetail" then
        --Spring.SendCommands('set GrassDetail ' .. tostring(math.ceil(value)))
        Spring.SetConfigInt("GrassDetail", math.ceil(value), true)
    end
end

function GrassEditor:IsValidTest(state)
    return state:is_A(GrassEditingState)
end

function GrassEditor:OnLeaveState(state)
    for _, btn in pairs({self.btnAddGrass}) do
        btn:SetPressedState(false)
    end
end

function GrassEditor:OnEnterState(state)
    self.btnAddGrass:SetPressedState(true)
end
