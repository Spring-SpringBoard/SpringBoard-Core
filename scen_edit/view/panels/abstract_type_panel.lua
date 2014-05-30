AbstractTypePanel = LCS.class.abstract{}

function AbstractTypePanel:init(dataType, parent, sources)
    self.dataType = dataType
    self.parent = parent
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
end

-- abstract
function AbstractTypePanel:UpdatePanel(field)
end
