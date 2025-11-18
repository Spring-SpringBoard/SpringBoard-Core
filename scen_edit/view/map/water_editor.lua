SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

WaterEditor = Editor:extends{}
WaterEditor:Register({
    name = "waterEditor",
    tab = "Env",
    caption = "Water",
    tooltip = "Edit water",
    image = Path.Join(SB.DIRS.IMG, 'wave-crest.png'),
    order = 2,
})

function WaterEditor:init(model)
    self:super("init")
    self.model = model or WaterEditorModel()

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    self:UpdateWaterRendering()

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }

    SB.commandManager:addListener(self)
    self:Finalize(children)
end

function WaterEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "asset" then
        self:AddField(AssetField({
            name = fieldDef.name,
            title = fieldDef.title,
            width = fieldDef.width,
            tooltip = fieldDef.tooltip,
            caption = fieldDef.caption,
        }))
    elseif fieldDef.type == "separator" then
        self:AddControl(fieldDef.name, {
            Label:New {
                caption = fieldDef.caption,
            },
            Line:New {
                x = 150,
            }
        })
    elseif fieldDef.type == "group" then
        local groupFields = {}
        for _, subFieldDef in ipairs(fieldDef.fields) do
            if subFieldDef.type == "numeric" then
                table.insert(groupFields, NumericField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = subFieldDef.width,
                    tooltip = subFieldDef.tooltip,
                    minValue = subFieldDef.min,
                    maxValue = subFieldDef.max,
                    value = subFieldDef.value,
                }))
            elseif subFieldDef.type == "boolean" then
                table.insert(groupFields, BooleanField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = subFieldDef.width,
                    tooltip = subFieldDef.tooltip,
                }))
            elseif subFieldDef.type == "color" then
                table.insert(groupFields, ColorField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = subFieldDef.width,
                    tooltip = subFieldDef.tooltip,
                    format = subFieldDef.format,
                }))
            elseif subFieldDef.type == "asset" then
                table.insert(groupFields, AssetField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = subFieldDef.width,
                    caption = subFieldDef.caption,
                }))
            end
        end
        self:AddField(GroupField(groupFields))
    end
end

function WaterEditor:UpdateWaterRendering()
    self.updating = true

    local params = self.model:UpdateWaterRendering()
    if params then
        for name, value in pairs(params) do
            self:Set(name, value)
        end
    end

    self.updating = false
end

function WaterEditor:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateWaterRendering()
    end
end

function WaterEditor:OnStartChange(name)
    self.model:OnStartChange()
end

function WaterEditor:OnEndChange(name)
    self.model:OnEndChange()
end

function WaterEditor:OnFieldChange(name, value)
    if self.updating then
        return
    end

    self.model:OnFieldChange(name, value)
end
