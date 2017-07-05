TypePanel = Editor:extends{}

function TypePanel:init(opts)
    Editor.init(self)

    self.stackPanel = opts.parent

    assert(opts.dataType, "dataType cannot be nil")
    assert(opts.parent, "parent cannot be nil")
    --assert(opts.trigger, "trigger cannot be nil")
    assert(opts.params, "params cannot be nil")

    self.dataType = opts.dataType
    -- self.parent = StackPanel:New {
    --     itemMargin = {0, 0, 0, 0},
    --     x = 1,
    --     y = 1,
    --     right = 1,
    --     autosize = true,
    --     resizeItems = false,
    --     padding = {0, 0, 0, 0},
    --     parent = opts.parent,
    -- }
    self.sources = opts.dataType.sources or {"pred", "spec", "var", "expr"}
    if type(self.sources) == "string" then
        self.sources = {self.sources}
    end
    self.radioButtons = {}
    self.trigger = opts.trigger
    self.params = opts.params
    self.FieldType = opts.FieldType
    self.parent = opts.parent

    self.width = 140

    for _, source in pairs(self.sources) do
        if source == "pred" then
            self:MakePredefinedOpt()
        elseif source == "spec" then
            self:MakeSpecialOpt()
        elseif source == "var" then
            self:MakeVariableOpt()
        elseif source == "expr" then
            self:MakeExpressionOpt()
        end
    end

    local children = {
        self.stackPanel,
    }

    -- table.insert(children,
    --     ScrollPanel:New {
    --         x = 0,
    --         y = 0,
    --         bottom = 0,
    --         right = 0,
    --         borderColor = {0,0,0,0},
    --         horizontalScrollbar = false,
    --         children = { self.stackPanel },
    --     }
    -- )
    -- self:Finalize(children, {noCloseButton = true, haxxor = true})
    -- opts.parent:AddChild(self.window)
    -- self.window:Show()

    self.__initializing = false
end

-- abstract
function TypePanel:MakePredefinedOpt()
    self:AddField(GroupField({
        BooleanField({
            name = "cbPredefined",
            title = "Predefined:",
            width = self.width,
        }),
        -- Uses a FieldType specified in the constructor
        self.FieldType({
            name = "predefined",
            width = self.width,
        })
    }))
    table.insert(self.radioButtons, "cbPredefined")
end

function TypePanel:MakeSpecialOpt()
    local validParams = {}
    for _, param in pairs(self.params) do
        if param.type == self.dataType.type then
            table.insert(validParams, param)
        end
    end
    if #validParams == 0 then
        return
    end

    self:AddField(GroupField({
        BooleanField({
            name = "cbSpecial",
            title = "Special " .. self.dataType.type .. ": ",
            width = self.width,
            value = false,
        }),
        ChoiceField({
            name = "cmbSpecial",
            width = self.width,
            items = GetField(validParams, "name"),
        })
    }))

    table.insert(self.radioButtons, "cbSpecial")
end

function TypePanel:MakeVariableOpt()
    --VARIABLE
    local variablesOfType = SB.model.variableManager:getVariablesOfType(self.dataType.type)
    if not variablesOfType then
        return
    end
    local variableNames = {}
    local variableIDs = {}
    for id, variable in pairs(variablesOfType) do
        table.insert(variableNames, variable.name)
        table.insert(variableIDs, id)
    end

    if #variableIDs == 0 then
        return
    end

    self:AddField(GroupField({
        BooleanField({
            name = "cbVariable",
            title = "Variable: ",
            width = self.width,
            value = false,
        }),
        ChoiceField({
            name = "cmbVariable",
            width = self.width,
            captions = variableNames,
            items = variableIDs,
        })
    }))
    table.insert(self.radioButtons, "cbVariable")
end

function TypePanel:MakeExpressionOpt()
    --EXPRESSION
    local viableExpressions = SB.metaModel.functionTypesByOutput[self.dataType.type]
    if not viableExpressions then
        return
    end

    local stackPanel = MakeComponentPanel(parent)
    self:AddField(GroupField({
        BooleanField({
            name = "cbExpression",
            title = "Expression: ",
            width = self.width,
        }),
        Field({
            name = "expression",
            width = self.width,
            components = {
                Button:New {
                    caption = 'Expression',
                    width = self.width,
                    height = 30,
                    data = {},
                    OnClick = {
                        function()
                            local mode = 'add'
                            local expr = self.fields["expression"].value
                            if expr then
                                mode = 'edit'
                            end
                            local customWindow = CustomWindow({
                                mode = mode,
                                dataType = self.dataType,
                                condition = expr,
                                trigger = self.trigger,
                                params = self.params,

                                OnConfirm = {
                                    function(element)
                                        if self.fields["cbExpression"] and not self.fields["cbExpression"].value then
                                            self:Set("cbExpression", true)
                                        end

                                        if mode == 'add' then
                                            expr = element
                                        end
                                        self:Set("expression", expr)
                                    end
                                }
                            })
                            SB.MakeWindowModal(customWindow.window, self.parent)
                        end
                    }
                }
            }
        })
    }))
    table.insert(self.radioButtons, "cbExpression")
end

-- abstract
function TypePanel:UpdateModel(field)
    if self.fields["cbPredefined"] and self.fields["cbPredefined"].value then
        field.type = "pred"
        field.value = self.fields["predefined"].value
        return true
    elseif self.fields["cbSpecial"] and self.fields["cbSpecial"].value then
        field.type = "spec"
        field.name = self.fields["cmbSpecial"].value
        return true
    elseif self.fields["cbVariable"] and self.fields["cbVariable"].value then
        field.type = "var"
        field.value = self.fields["cmbVariable"].value
        return true
    elseif self.fields["cbExpression"] and self.fields["cbExpression"].value and self.fields["expression"].value then
        field.type = "expr"
        field.expr = self.fields["expression"].value
        return true
    end
    return false
end

-- abstract
function TypePanel:UpdatePanel(field)
    if field.type == "pred" then
        self:Set("cbPredefined", true)
        self:Set("predefined", field.value)
        return true
    elseif field.type == "spec" then
        self:Set("cbSpecial", true)
        self:Set("cmbSpecial", field.name)
        return true
    elseif field.type == "var" then
        self:Set("cbVariable", true)
        self:Set("cmbVariable", field.value)
        return true
    elseif field.type == "expr" then
        self:Set("cbExpression", true)
        self:Set("expression", field.value)
        return true
    end
    return false
end

function TypePanel:OnFieldChange(name, value)
    if value then
        local isRadioButton = false
        for _, radioButton in pairs(self.radioButtons) do
            if radioButton == name then
                isRadioButton = true
            end
        end
        if isRadioButton then
            for _, radioButton in pairs(self.radioButtons) do
                if radioButton ~= name then
                    self:Set(radioButton, false)
                end
            end
        end
    end

    if name == "predefined" then
        self:Set("cbPredefined", true)
    elseif name == "cmbSpecial" then
        self:Set("cbSpecial", true)
    elseif name == "cmbVariable" then
        self:Set("cbVariable", true)
    elseif name == "expression" then
        self:Set("cbExpression", true)
        local tooltip = SB.humanExpression(value, "condition")
        self.fields["expression"].components[1].tooltip = tooltip
    end
end
