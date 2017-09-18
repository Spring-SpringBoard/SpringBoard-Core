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

    self:AddControl("btn-show-metal", {
        Button:New {
            caption = "Show metal map",
            width = 200,
            height = 40,
            OnClick = {
                function()
                    Spring.SendCommands('showmetalmap')
                end
            }
        },
    })

    self:AddField(NumericField({
        name = "size",
        value = 100,
        minValue = 40,
        maxValue = 1000,
        title = "Size:",
        tooltip = "Size of the paint brush",
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
        value = 50,
        step = 0.1,
        title = "Strength:",
        tooltip = "Strength of the height map tool",
    }))
    self:AddField(NumericField({
        name = "amount",
        value = 50,
        minValue = 0,
        maxValue = 10000,
        step = 0.01,
        title = "Amount:",
        tooltip = "Amount of metal",
    }))

    local children = {
        self.btnAddMetal,
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

function MetalEditor:IsValidState(state)
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
