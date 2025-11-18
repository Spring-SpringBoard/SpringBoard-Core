SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

SkyEditor = Editor:extends{}
SkyEditor:Register({
    name = "skyEditor",
    tab = "Env",
    caption = "Sky",
    tooltip = "Edit sky and fog",
    image = Path.Join(SB.DIRS.IMG, 'night-sky.png'),
    order = 1,
})

function SkyEditor:init(model)
    self:super("init")
    self.model = model or SkyEditorModel()

    local fieldDefs = self.model:GetFieldDefinitions()
    for _, fieldDef in ipairs(fieldDefs) do
        self:AddFieldFromDef(fieldDef)
    end

    self:UpdateAtmosphere()

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

function SkyEditor:AddFieldFromDef(fieldDef)
    if fieldDef.type == "asset" then
        self:AddField(AssetField({
            name = fieldDef.name,
            title = fieldDef.title,
            tooltip = fieldDef.tooltip,
            rootDir = fieldDef.rootDir,
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
                }))
            elseif subFieldDef.type == "color" then
                table.insert(groupFields, ColorField({
                    name = subFieldDef.name,
                    title = subFieldDef.title,
                    width = subFieldDef.width,
                    tooltip = subFieldDef.tooltip,
                    format = subFieldDef.format,
                }))
            end
        end
        self:AddField(GroupField(groupFields))
    end
end

function SkyEditor:UpdateAtmosphere()
    self.updating = true

    local params = self.model:UpdateAtmosphere()
    for name, value in pairs(params) do
        self:Set(name, value)
    end

    self.updating = false
end

function SkyEditor:OnCommandExecuted()
    if not self._startedChanging then
        self:UpdateAtmosphere()
    end
end

function SkyEditor:OnStartChange(name)
    self.model:OnStartChange()
end

function SkyEditor:OnEndChange(name)
    self.model:OnEndChange()
end

function SkyEditor:OnFieldChange(name, value)
    if self.updating then
        return
    end

    self.model:OnFieldChange(name, value)
end
