AbstractTypePanel = LCS.class.abstract{}

function AbstractTypePanel:init(dataType, parent, sources)
    self.dataType = dataType
    self.parent = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0},
        parent = parent,
    }
    sources = sources or {"pred", "spec", "variable", "expression"}
    if type(sources) == "string" then
        sources = {sources}
    end
    self.sources = sources
    self.radioGroup = {}

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

-- abstract
function AbstractTypePanel:MakeSpecialOpt()
end

function AbstractTypePanel:MakeVariableOpt()
    --VARIABLE
    self.cbVariable, self.cmbVariable = MakeVariableChoice(self.dataType, self.parent)
    if self.cbVariable then
        table.insert(self.radioGroup, self.cbVariable)
    end
end

function AbstractTypePanel:MakeExpressionOpt()
    --EXPRESSION
    self.cbExpression, self.btnExpression = SCEN_EDIT.AddExpression(self.dataType, self.parent)
    if self.cbExpression then
        table.insert(self.radioGroup, self.cbExpression)
    end
end

-- abstract
function AbstractTypePanel:UpdateModel(field)
    if self.cbVariable and self.cbVariable.checked then
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
    if field.type == "var" then
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
        return true
    end
    return false
end
