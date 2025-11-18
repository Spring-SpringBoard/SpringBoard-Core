SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

GrassEditor = Editor:extends{}
GrassEditor:Register({
    name = "grassEditor",
    tab = "Map",
    caption = "Grass",
    tooltip = "Edit grass",
    image = Path.Join(SB.DIRS.IMG, 'grass.png'),
    order = 4,
})

function GrassEditor:init(model)
    self:super("init")
    self.model = model or GrassEditorModel()

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
                step = fieldDef.step,
                title = fieldDef.title,
                tooltip = fieldDef.tooltip,
            }))
        end
    end

    self.btnAddGrass = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Left Click to add grass, Right Click to remove it.",
        children = {
            TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, 'grass-add.png') }),
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

    local children = {
        self.btnAddGrass,
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

function GrassEditor:OnFieldChange(name, value)
    self.model:OnFieldChange(name, value)
end

function GrassEditor:IsValidState(state)
    return self.model:IsValidState(state)
end

function GrassEditor:OnLeaveState(state)
    self.btnAddGrass:SetPressedState(false)
end

function GrassEditor:OnEnterState(state)
    self.btnAddGrass:SetPressedState(true)
end
