--- RmlUi Metal Editor

RmlUiMetalEditor = RmlUiEditorBase:extends{}

function RmlUiMetalEditor:init(model)
    self:super("init")
    self.model = model or MetalEditorModel()
    self.editorTitle = "Metal Editor"

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
                title = fieldDef.title,
                tooltip = fieldDef.tooltip,
                width = 200,
            }))
        end
    end

    self:AddButton({
        caption = "Show Metal Map",
        onClick = function()
            self.model:ShowMetalMap()
        end
    })
end

function RmlUiMetalEditor:OnFieldChange(name, value)
    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        if fieldDef.name == name and fieldDef.updateFunc then
            fieldDef.updateFunc(value)
        end
    end
end

function RmlUiMetalEditor:IsValidState(state)
    return self.model:IsValidState(state)
end
