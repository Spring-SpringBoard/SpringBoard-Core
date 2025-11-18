--- RmlUi Heightmap Editor
--- 100% programmatic - no RML file needed!

RmlUiHeightmapEditor = RmlUiEditorBase:extends{}

function RmlUiHeightmapEditor:init(model)
    self:super("init")
    self.model = model or HeightmapEditorModel()
    self.editorTitle = "Heightmap Editor"

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
            }))
        elseif fieldDef.type == "numeric" then
            self:AddField(NumericField({
                name = fieldDef.name,
                title = fieldDef.title,
                value = fieldDef.value,
                min = fieldDef.min,
                max = fieldDef.max,
                step = fieldDef.step,
                tooltip = fieldDef.tooltip,
                width = 200,
            }))
        elseif fieldDef.type == "choice" then
            self:AddField(ChoiceField({
                name = fieldDef.name,
                items = fieldDef.items,
                tooltip = fieldDef.tooltip,
                width = 200,
            }))
        end
    end

    local toolModes = self.model:GetToolModes()
    for _, toolMode in ipairs(toolModes) do
        self:AddToolButton({
            id = toolMode.id,
            caption = toolMode.caption,
            tooltip = toolMode.tooltip,
            icon = toolMode.icon,
            onClick = function()
                self.model:ActivateTool(toolMode.id, self)
            end
        })
    end

    self:AddButton({
        caption = "Show Elevation",
        onClick = function()
            self.model:ShowElevation()
        end
    })

    self:UpdateFieldVisibility()
end

function RmlUiHeightmapEditor:UpdateFieldVisibility()
    local visibleFields = self.model:GetVisibleFieldsForMode(self.model:GetCurrentMode())
    local allFields = {"patternTexture", "size", "rotation", "strength", "height", "applyDir"}

    for _, field in ipairs(allFields) do
        local isVisible = false
        for _, vf in ipairs(visibleFields) do
            if vf == field then
                isVisible = true
                break
            end
        end
        self:SetFieldVisible(field, isVisible)
    end
end

function RmlUiHeightmapEditor:OnFieldChange(name, value)
    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        if fieldDef.name == name and fieldDef.updateFunc then
            fieldDef.updateFunc(value)
        end
    end
end

function RmlUiHeightmapEditor:IsValidState(state)
    return self.model:IsValidState(state)
end

function RmlUiHeightmapEditor:OnEnterState(state)
    local modeId
    if state:is_A(TerrainShapeModifyState) then
        modeId = "add"
    elseif state:is_A(TerrainSetState) then
        modeId = "set"
    elseif state:is_A(TerrainSmoothState) then
        modeId = "smooth"
    end

    self.model:SetMode(modeId)
    self:UpdateFieldVisibility()
    self:SetActiveToolButton(modeId)
end

function RmlUiHeightmapEditor:OnLeaveState(state)
    self:ClearActiveToolButton()
end

function RmlUiHeightmapEditor:Update()
    -- Stub
end
