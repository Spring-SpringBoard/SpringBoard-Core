SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

MetalEditor = Editor:extends{}
MetalEditor:Register({
    name = "metalEditor",
    tab = "Map",
    caption = "Metal",
    tooltip = "Edit metal map",
    image = Path.Join(SB.DIRS.IMG, 'minerals.png'),
    order = 3,
})

function MetalEditor:init(model)
    self:super("init")
    self.model = model or MetalEditorModel()

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        if fieldDef.type == "asset" then
            self:AddField(AssetField({
                name = fieldDef.name,
                title = fieldDef.title,
                rootDir = fieldDef.rootDir,
                expand = fieldDef.expand,
                itemWidth = fieldDef.itemWidth,
                itemHeight = fieldDef.itemHeight,
                Validate = fieldDef.validateFunc,
                Update = function(...)
                    AssetField.Update(...)
                    local value = self.fields[fieldDef.name].value
                    fieldDef.updateFunc(value)
                end
            }))
        elseif fieldDef.type == "numeric" then
            self:AddField(NumericField({
                name = fieldDef.name,
                value = fieldDef.value,
                minValue = fieldDef.min,
                maxValue = fieldDef.max,
                title = fieldDef.title,
                tooltip = fieldDef.tooltip,
            }))
        end
    end

    self.btnSetMetal = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Left Click to set metal. Right click to remove it.",
        children = {
            TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, 'metal-add.png') }),
            TabbedPanelLabel({ caption = "Set" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(MetalEditingState(self))
            end
        },
    })
    self:AddDefaultKeybinding({
        self.btnSetMetal
    })

    self:AddControl("btn-show-metal", {
        Button:New {
            caption = "Show metal map",
            width = 200,
            height = 40,
            OnClick = {
                function()
                    self.model:ShowMetalMap()
                end
            }
        },
    })

    local children = {
        self.btnSetMetal,
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
    return self.model:IsValidState(state)
end

function MetalEditor:OnLeaveState(state)
    self.btnSetMetal:SetPressedState(false)
end

function MetalEditor:OnEnterState(state)
    self.btnSetMetal:SetPressedState(true)
end
