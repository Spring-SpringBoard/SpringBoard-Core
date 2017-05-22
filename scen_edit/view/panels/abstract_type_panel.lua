AbstractTypePanel = LCS.class.abstract{}

function AbstractTypePanel:init(opts)
    self.dataType = opts.dataType
    self.parent = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0},
        parent = opts.parent,
    }
    self.sources = opts.sources or {"pred", "spec", "variable", "expression"}
    if type(self.sources) == "string" then
        self.sources = {self.sources}
    end
    self.radioGroup = {}
    self.trigger = opts.trigger

    for _, source in pairs(self.sources) do
        if source == "pred" then
            self:MakePredefinedOpt()
        elseif source == "spec" then
            self:MakeSpecialOpt()
        elseif source == "variable" then
            self:MakeVariableOpt()
        elseif source == "expression" then
            self:MakeExpressionOpt()
        end
    end

    if #self.radioGroup > 0 then
        SCEN_EDIT.MakeRadioButtonGroup(self.radioGroup)
    end
end

-- abstract
function AbstractTypePanel:MakePredefinedOpt()
end

function AbstractTypePanel:MakeSpecialOpt()
    if self.trigger and #self.trigger.events == 0 then
        return
    end
    local validParams = {}
    for _, event in pairs(self.trigger.events) do
        local typeName = event.typeName
        local eventType = SCEN_EDIT.metaModel.eventTypes[typeName]
        for _, param in pairs(eventType.param) do
            if param.type == self.dataType.type then
                table.insert(validParams, "Trigger: " .. param.name)
            end
        end
    end
    if #validParams == 0 then
        return
    end

    --SPECIAL object, i.e TRIGGER
    local stackPanel = MakeComponentPanel(self.parent)
    local isChecked = true
    if self.cbPredefined and self.cbPredefined.checked then
        isChecked = false
    end
    self.cbSpecial = Checkbox:New {
        caption = "Special " .. self.dataType.type .. ": ",
        right = 100 + 10,
        x = 1,
        checked = isChecked,
        parent = stackPanel,
    }
    table.insert(self.radioGroup, self.cbSpecial)
    self.cmbSpecial = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackPanel,
        items = validParams,
    }
    self.cmbSpecial.OnSelect = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                if not self.cbSpecial.checked then
                    self.cbSpecial:Toggle()
                end
            end
        end
    }
end

function AbstractTypePanel:MakeVariableOpt()
    --VARIABLE
    self.cbVariable, self.cmbVariable = self:MakeVariableChoice(self.dataType.type, self.parent)
    if self.cbVariable then
        table.insert(self.radioGroup, self.cbVariable)
    end
end

function AbstractTypePanel:MakeExpressionOpt()
    --EXPRESSION
    self.cbExpression, self.btnExpression = self:AddExpression(self.dataType, self.parent)
    if self.cbExpression then
        table.insert(self.radioGroup, self.cbExpression)
    end
end

-- abstract
function AbstractTypePanel:UpdateModel(field)
    if self.cbSpecial and self.cbSpecial.checked then
        field.type = "spec"
        field.name = self.cmbSpecial.items[self.cmbSpecial.selected]
        return true
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
        return true
    elseif self.cbExpression and self.cbExpression.checked and self.btnExpression.data ~= nil  and #self.btnExpression.data ~= 0 then
        field.type = "expr"
        field.expr = self.btnExpression.data
        return true
    end
    return false
end

-- abstract
function AbstractTypePanel:UpdatePanel(field)
    if field.type == "spec" then
        if not self.cbSpecial.checked then
            self.cbSpecial:Toggle()
        end
        self.cmbSpecial:Select(1) --TODO:fix it
        return true
    elseif field.type == "var" then
        if not self.cbVariable.checked then
            self.cbVariable:Toggle()
        end
        for i = 1, #self.cmbVariable.variableIds do
            local variableId = self.cmbVariable.variableIds[i]
            if variableId == field.id then
                self.cmbVariable:Select(i)
                break
            end
        end
        return true
    elseif field.type == "expr" then
        if not self.cbExpression.checked then
            self.cbExpression:Toggle()
        end
        self.btnExpression.data = field.expr
        local tooltip = SCEN_EDIT.humanExpression(self.btnExpression.data[1], "condition")
        self.btnExpression.tooltip = tooltip
        return true
    end
    return false
end

function AbstractTypePanel:AddExpression(dataType, parent)
    local viableExpressions = SCEN_EDIT.metaModel.functionTypesByOutput[dataType.type]
    if viableExpressions then
        local stackPanel = MakeComponentPanel(parent)
        local cbExpressions = Checkbox:New {
            caption = "Expression: ",
            right = 100 + 10,
            x = 1,
            checked = false,
            parent = stackPanel,
        }
        local btnExpressions = Button:New {
            caption = 'Expression',
            right = 1,
            width = 100,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
            data = {},
        }
        btnExpressions.OnClick = {
            function()
                local mode = 'add'
                if #btnExpressions.data > 0 then
                    mode = 'edit'
                end
                CustomWindow({
                    parentWindow = parent.parent.parent,
                    mode = mode,
                    dataType = dataType,
                    parentObj = btnExpressions.data,
                    condition = btnExpressions.data[1],
                    cbExpressions = cbExpressions,
                    btnExpressions = btnExpressions,
                    trigger = self.trigger
                })
            end
        }
        return cbExpressions, btnExpressions
    end
    return nil, nil
end

function AbstractTypePanel:MakeVariableChoice(variableType, panel)
    local variablesOfType = SCEN_EDIT.model.variableManager:getVariablesOfType(variableType)
    if not variablesOfType then
        return nil, nil
    end
    local variableNames = {}
    local variableIds = {}
    for id, variable in pairs(variablesOfType) do
        table.insert(variableNames, variable.name)
        table.insert(variableIds, id)
    end

    if #variableIds > 0 then
        local stackPanel = MakeComponentPanel(panel)
        local cbVariable = Checkbox:New {
            caption = "Variable: ",
            right = 100 + 10,
            x = 1,
            checked = false,
            parent = stackPanel,
        }

        local cmbVariable = ComboBox:New {
            right = 1,
            width = 100,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
            items = variableNames,
            variableIds = variableIds,
        }
        cmbVariable.OnSelect = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    if not cbVariable.checked then
                        cbVariable:Toggle()
                    end
                end
            end
        }
        return cbVariable, cmbVariable
    else
        return nil, nil
    end
end
