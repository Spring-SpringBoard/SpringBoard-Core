--- RmlUi Texture Editor
--- 100% programmatic - no RML file needed!

RmlUiTextureEditor = RmlUiEditorBase:extends{}

function RmlUiTextureEditor:init(model)
    self:super("init")
    self.model = model or TextureEditorModel()
    self.editorTitle = "Texture Editor"
    self.matFieldNames = {}

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    local matFields = self.model:GetMaterialTextureFields()
    for _, fieldDef in ipairs(matFields) do
        self:AddField(BooleanField({
            name = fieldDef.name,
            value = fieldDef.value,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            width = fieldDef.width,
        }))
        table.insert(self.matFieldNames, fieldDef.name)
    end

    local toolModes = self.model:GetToolModes()
    for _, toolMode in ipairs(toolModes) do
        self:AddToolButton({
            id = toolMode.id,
            caption = toolMode.caption,
            tooltip = toolMode.tooltip,
            icon = toolMode.icon,
            onClick = function()
                self:EnterToolMode(toolMode.id)
            end
        })
    end

    self:UpdateFieldVisibility()
end

function RmlUiTextureEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "asset" then
        self:AddField(AssetField({
            name = fieldDef.name,
            title = fieldDef.title,
            rootDir = fieldDef.rootDir,
            expand = fieldDef.expand,
            itemWidth = fieldDef.itemWidth,
            itemHeight = fieldDef.itemHeight,
        }))
    elseif fieldDef.type == "material" then
        self:AddField(MaterialField({
            name = fieldDef.name,
            title = fieldDef.title,
            value = fieldDef.value,
            rootDir = fieldDef.rootDir,
            width = fieldDef.width,
        }))
    elseif fieldDef.type == "choice" then
        self:AddField(ChoiceField({
            name = fieldDef.name,
            items = fieldDef.items,
            title = fieldDef.title,
            width = 200,
        }))
    elseif fieldDef.type == "boolean" then
        self:AddField(BooleanField({
            name = fieldDef.name,
            title = fieldDef.title,
            value = fieldDef.value,
            width = 200,
        }))
    elseif fieldDef.type == "color" then
        self:AddField(ColorField({
            name = fieldDef.name,
            title = fieldDef.title,
            value = fieldDef.value,
            width = fieldDef.width,
            format = fieldDef.format,
        }))
    elseif fieldDef.type == "hidden" then
        self:AddField(Field({
            name = fieldDef.name,
            value = fieldDef.value,
        }))
    elseif fieldDef.type == "separator" or fieldDef.type == "group" then
        -- Skip separators and groups in RmlUi, just add the fields
        if fieldDef.type == "group" and fieldDef.fields then
            for _, subFieldDef in ipairs(fieldDef.fields) do
                if subFieldDef.type == "numeric" then
                    self:AddField(NumericField({
                        name = subFieldDef.name,
                        title = subFieldDef.title,
                        value = subFieldDef.value,
                        min = subFieldDef.min,
                        max = subFieldDef.max,
                        step = subFieldDef.step,
                        decimals = subFieldDef.decimals,
                        tooltip = subFieldDef.tooltip,
                        width = 200,
                    }))
                end
            end
        end
    end
end

function RmlUiTextureEditor:EnterToolMode(modeId)
    self.model:SetMode(modeId)
    self:UpdateFieldVisibility()
    self:SetActiveToolButton(modeId)
end

function RmlUiTextureEditor:UpdateFieldVisibility()
    local visibleFields = self.model:GetVisibleFieldsForMode(self.model:GetCurrentMode())
    local allFields = {"patternTexture", "brushTexture", "mode", "kernelMode", "exclusive",
                      "size", "rotation", "texScale", "texRotation", "texOffsetX", "texOffsetY",
                      "strength", "falloffFactor", "featureFactor", "value", "voidFactor",
                      "splatTexScale", "splatTexMult", "diffuseColor"}

    for _, matFieldName in ipairs(self.matFieldNames) do
        table.insert(allFields, matFieldName)
    end

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

function RmlUiTextureEditor:OnStartChange(name)
    self.model:OnStartChange(name)
end

function RmlUiTextureEditor:OnEndChange(name)
    self.model:OnEndChange(name)
end

function RmlUiTextureEditor:OnFieldChange(name, value)
    -- Note: savedBrushes not implemented in RmlUi yet, so pass nil
    -- self.model:HandleFieldChange(name, value, nil, nil, self.fields)
end

function RmlUiTextureEditor:IsValidState(state)
    return self.model:IsValidState(state)
end

function RmlUiTextureEditor:OnEnterState(state)
    local modeId = state.paintMode
    self.model:SetMode(modeId)
    self:UpdateFieldVisibility()
    self:SetActiveToolButton(modeId)
end

function RmlUiTextureEditor:OnLeaveState(state)
    self:ClearActiveToolButton()
end

function RmlUiTextureEditor:Update()
    -- Stub
end
