SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

VariableWindow = Editor:extends{}

function VariableWindow:init(opts)
    Editor.init(self)

    self.variable = opts.variable
    self.OnConfirm = opts.OnConfirm or {}

    local btnOK = Button:New {
        caption = 'OK',
        width = '40%',
        x = 1,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        classname = "option_button",
        OnClick = {
            function()
                self:ConfirmDialog()
            end
        }
    }
    local btnCancel = Button:New {
        caption = 'Cancel',
        width = '40%',
        x = '50%',
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        classname = "negative_button",
        OnClick = {
            function()
                self.window:Dispose()
            end
        }
    }

    self:AddField(StringField({
        name = "name",
        title = "Name:",
        tooltip = "Variable name",
        text = self.variable.name,
    }))

    self:AddField(ChoiceField({
        name = "type",
        title = "Type:",
        items = SB.metaModel.variableTypes,
        width = 300,
    }))

    self:Set("type", self.variable.type)

    self.variablePanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        y = 110,
        x = 0,
        right = 0,
        bottom = 0,
        padding = {0, 0, 0, 0}
    }

    local children = {
        btnOK,
        btnCancel,
        self.variablePanel
    }

    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )

    self:Finalize(children, {
        notMainWindow = true,
        noCloseButton = true,
        x = tostring(math.random(30, 40)) .. "%",
        y = tostring(math.random(30, 40)) .. "%",
        width = 500,
        height = 200,
        classname = "sb_window",
    })

    self:__RefreshVariablePanel()
end

function VariableWindow:ConfirmDialog()
    if self:UpdateModel(self.variable) then
        self.window:Dispose()
    end
end

function VariableWindow:__RefreshVariablePanel()
    self.variablePanel:ClearChildren()

    local inputType = self.fields["type"].value
    local subPanel = SB.createNewPanel({
        dataType = {
            type = inputType,
            sources = "const",
            allowNil = true,
        },
        parent = self.variablePanel,
        params = {},
    })
    if subPanel then
        --SB.MakeSeparator(self.variablePanel)
        self.variablePanel[inputType] = subPanel
    end
end

function VariableWindow:OnFieldChange(name, value)
    if name == "type" then
        self:__RefreshVariablePanel()
    end
end

function VariableWindow:UpdatePanel(variable)
    self.variable = variable

    self:Set("name", self.variable.name)
    self:Set("type", self.variable.type)
    if self.variable.value then
        self.variablePanel[self.variable.type]:UpdatePanel(self.variable.value)
    end
end

function VariableWindow:UpdateModel(variable)
    variable.name = self.fields["name"].value
    local newVariableType = self.fields["type"].value
    --[[
    local typeChanged = false
    if variable.type ~= newVarType then
        typeChanged = true
    end
    --]]
    variable.type = newVariableType
    variable.value = {}
    if not self.variablePanel[variable.type]:UpdateModel(self.variable.value) then
        return false, self.variablePanel[variable.type]
    end

    CallListeners(self.OnConfirm, variable)
    return true


--[[    if typeChanged then
        SB.model:RemoveVariable(variable.id)
        newVariable = SB.model:NewVariable(variable.type)
        newVariable.value = variable.value
        newVariable.name = variable.name
    end--]]
end
