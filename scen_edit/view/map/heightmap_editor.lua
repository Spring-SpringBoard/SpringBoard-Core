SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

HeightmapEditor = Editor:extends{}
HeightmapEditor:Register({
    name = "heightmapEditor",
    tab = "Map",
    caption = "Terrain",
    tooltip = "Edit heightmap",
    image = Path.Join(SB.DIRS.IMG, 'peaks.png'),
    order = 0,
})

function HeightmapEditor:init(model)
    self:super("init")
    self.model = model or HeightmapEditorModel()

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
        elseif fieldDef.type == "choice" then
            self:AddField(ChoiceField({
                name = fieldDef.name,
                items = fieldDef.items,
                tooltip = fieldDef.tooltip,
            }))
        end
    end

    local toolModes = self.model:GetToolModes()
    self.toolButtons = {}
    for i, toolMode in ipairs(toolModes) do
        local x = (i - 1) * 70
        local btn = TabbedPanelButton({
            x = x,
            y = 0,
            tooltip = toolMode.tooltip,
            children = {
                TabbedPanelImage({ file = Path.Join(SB.DIRS.IMG, toolMode.icon) }),
                TabbedPanelLabel({ caption = toolMode.caption }),
            },
            OnClick = {
                function()
                    self.model:ActivateTool(toolMode.id, self)
                end
            },
        })
        self.toolButtons[toolMode.id] = btn
    end

    self:AddDefaultKeybinding({
        self.toolButtons["add"],
        self.toolButtons["set"],
        self.toolButtons["smooth"]
    })

    self:AddControl("btn-show-elevation", {
        Button:New {
            caption = "Show elevation",
            width = 200,
            height = 40,
            OnClick = {
                function()
                    self.model:ShowElevation()
                end
            }
        },
    })

    self:Update("size")
    local visibleFields = self.model:GetVisibleFieldsForMode(self.model:GetCurrentMode())
    local allFields = {"patternTexture", "size", "rotation", "strength", "height", "applyDir"}
    local invisibleFields = {}
    for _, field in ipairs(allFields) do
        local isVisible = false
        for _, vf in ipairs(visibleFields) do
            if vf == field then
                isVisible = true
                break
            end
        end
        if not isVisible then
            table.insert(invisibleFields, field)
        end
    end
    self:SetInvisibleFields(unpack(invisibleFields))

    local children = {
        self.toolButtons["add"],
        self.toolButtons["set"],
        self.toolButtons["smooth"],
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
    for _, btn in pairs(self.toolButtons) do
        btn:SetPressedState(false)
    end
end

function HeightmapEditor:OnEnterState(state)
    local modeId
    if state:is_A(TerrainShapeModifyState) then
        modeId = "add"
    elseif state:is_A(TerrainSetState) then
        modeId = "set"
    elseif state:is_A(TerrainSmoothState) then
        modeId = "smooth"
    end

    self.model:SetMode(modeId)
    self.toolButtons[modeId]:SetPressedState(true)

    local visibleFields = self.model:GetVisibleFieldsForMode(modeId)
    local allFields = {"patternTexture", "size", "rotation", "strength", "height", "applyDir"}
    local invisibleFields = {}
    for _, field in ipairs(allFields) do
        local isVisible = false
        for _, vf in ipairs(visibleFields) do
            if vf == field then
                isVisible = true
                break
            end
        end
        if not isVisible then
            table.insert(invisibleFields, field)
        end
    end
    self:SetInvisibleFields(unpack(invisibleFields))
end

function HeightmapEditor:IsValidState(state)
    return self.model:IsValidState(state)
end
