SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

LightingEditor = Editor:extends{}
LightingEditor:Register({
    name = "lightingEditor",
    tab = "Env",
    caption = "Lighting",
    tooltip = "Edit lighting",
    image = Path.Join(SB.DIRS.IMG, 'sunbeams.png'),
    order = 0,
})

function LightingEditor:init(model)
    self:super("init")
    self.model = model or LightingEditorModel()

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    self.fields["shadowMode"]:Set(self.model:GetInitialShadowMode())
    self:UpdateLighting()

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

function LightingEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "choice" then
        self:AddField(ChoiceField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            items = fieldDef.items,
            width = fieldDef.width,
        }))
    elseif fieldDef.type == "numeric" then
        self:AddField(NumericField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            value = fieldDef.value,
            minValue = fieldDef.min,
            maxValue = fieldDef.max,
            width = fieldDef.width,
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
                    tooltip = subFieldDef.tooltip,
                    value = subFieldDef.value,
                    step = subFieldDef.step,
                    width = subFieldDef.width,
                }))
            elseif subFieldDef.type == "color" then
                table.insert(groupFields, ColorField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    tooltip = subFieldDef.tooltip,
                    width = subFieldDef.width,
                    format = subFieldDef.format,
                }))
            end
        end
        self:AddField(GroupField(groupFields))
    end
end

function LightingEditor:UpdateLighting()
    self.updating = true

    local params = self.model:UpdateLighting()
    for name, value in pairs(params) do
        self:Set(name, value)
    end

    self.updating = false
end

function LightingEditor:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateLighting()
    end
end

function LightingEditor:OnStartChange(name)
    self.model:OnStartChange()
end

function LightingEditor:OnEndChange(name)
    self.model:OnEndChange()
end

function LightingEditor:OnFieldChange(name, value)
    if self.updating then
        return
    end

    self.model:OnFieldChange(name, value, self.fields)
end
