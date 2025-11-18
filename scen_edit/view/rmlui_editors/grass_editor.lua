--- RmlUi Grass Editor

RmlUiGrassEditor = RmlUiEditorBase:extends{}

function RmlUiGrassEditor:init(model)
    self:super("init")
    self.model = model or GrassEditorModel()
    self.editorTitle = "Grass Editor"

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
                value = fieldDef.value,
                min = fieldDef.min,
                max = fieldDef.max,
                step = fieldDef.step,
                title = fieldDef.title,
                tooltip = fieldDef.tooltip,
                width = 200,
            }))
        end
    end
end

function RmlUiGrassEditor:OnFieldChange(name, value)
    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        if fieldDef.name == name and fieldDef.updateFunc then
            fieldDef.updateFunc(value)
        end
    end
    self.model:OnFieldChange(name, value)
end

function RmlUiGrassEditor:IsValidState(state)
    return self.model:IsValidState(state)
end
