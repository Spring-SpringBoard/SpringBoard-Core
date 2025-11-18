SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_dialogs/base_dialog.lua'))

RmlUiNewProjectDialog = RmlUiBaseDialog:extends{}

function RmlUiNewProjectDialog:init(opts)
    opts = opts or {}
    opts.title = "New Project"
    self:super("init", opts)
    self.model = NewProjectDialogModel()

    self:AddField(StringField({
        name = "projectName",
        title = "Project name:",
        value = "",
        width = 300,
    }))

    local items, captions = self.model:GetMapItems()
    self:AddField(ChoiceField({
        name = "mapName",
        title = "Map:",
        items = items,
        captions = captions,
        width = 300,
    }))

    self:AddField(GroupField({
        fields = {
            NumericField({
                name = "sizeX",
                title = "Size X:",
                width = 140,
                min = 2,
                max = 32,
                step = 2,
                value = 10,
            }),
            NumericField({
                name = "sizeY",
                title = "Size Y:",
                width = 140,
                min = 2,
                max = 32,
                step = 2,
                value = 10,
            })
        }
    }))

    self:AddField(StringField({
        name = "error",
        title = "",
        value = "",
        width = 400,
    }))
end

function RmlUiNewProjectDialog:SetDialogError(error)
    if error then
        self:SetFieldValue("error", tostring(error))
    else
        self:SetFieldValue("error", "Unknown error")
    end
end

function RmlUiNewProjectDialog:ConfirmDialog()
    self:SetDialogError("")

    local projectName = self:GetFieldValue("projectName")
    local mapName = self:GetFieldValue("mapName")
    local sizeX = self:GetFieldValue("sizeX")
    local sizeY = self:GetFieldValue("sizeY")

    local success, error = self.model:CreateProject(projectName, mapName, sizeX, sizeY)

    if not success then
        self:SetDialogError(error)
        return false
    end

    return true
end

function RmlUiNewProjectDialog:OnFieldChange(name, value)
    if name == "mapName" then
        if self.model:ShouldShowSizeFields(value) then
            Log.Debug("Show blank map size fields")
        else
            Log.Debug("Hide blank map size fields")
        end
    end
end
