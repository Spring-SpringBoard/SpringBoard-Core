SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

NewProjectDialog = Editor:extends{}

function NewProjectDialog:init(model)
    self:super("init")
    self.model = model or NewProjectDialogModel()

    self:AddField(StringField({
        name = "projectName",
        title = "Project name:",
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
        NumericField({
            name = "sizeX",
            title = "Size X:",
            width = 140,
            minValue = 2,
            value = 10,
            maxValue = 32,
            step = 2,
            decimals = 0,
        }),
        NumericField({
            name = "sizeY",
            title = "Size Y:",
            width = 140,
            minValue = 1,
            value = 10,
            maxValue = 32,
            step = 2,
            decimals = 0,
        })
    }))

    self.error = Label:New {
        font = {
            color = { 1, 0, 0, 1 },
        },
        caption = ""
    }
    self:AddControl('error', { self.error })

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

    self:Finalize(children, {
        notMainWindow = true,
        buttons = { "ok", "cancel" },
        width = 400,
        height = 300,
    })
end

function NewProjectDialog:SetDialogError(error)
    if error then
        self.error:SetCaption(tostring(error))
    else
        self.error:SetCaption('Unknown error')
    end
end

function NewProjectDialog:ConfirmDialog()
    self:SetDialogError("")

    local projectName = self.fields["projectName"].value
    local mapName = self.fields["mapName"].value
    local sizeX = self.fields["sizeX"].value
    local sizeY = self.fields["sizeY"].value

    local success, error = self.model:CreateProject(projectName, mapName, sizeX, sizeY)

    if not success then
        if error:match("project name") then
            SB.HintControls(self.fields["projectName"].components)
        elseif error:match("sizeX") then
            SB.HintControls(self.fields["sizeX"].components)
        elseif error:match("sizeY") then
            SB.HintControls(self.fields["sizeY"].components)
        end
        self:SetDialogError(error)
        return
    end
end

function NewProjectDialog:OnFieldChange(name, value)
    if name == "mapName" then
        if self.model:ShouldShowSizeFields(value) then
            self:SetInvisibleFields()
        else
            self:SetInvisibleFields("sizeX", "sizeY")
        end
    end
end
