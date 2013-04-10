StringPanel = {
}

function StringPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function StringPanel:Initialize()
    local radioGroup = {}
    local stackStringPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedString = Checkbox:New {
        caption = "Predefined string: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackStringPanel,
    }    
    table.insert(radioGroup, self.cbPredefinedString)
    self.edString = EditBox:New {
        text = "text",
        right = 1,
        width = 100,
        parent = stackStringPanel,
    }
    
    --VARIABLE
    self.cbVariable, self.cmbVariable = MakeVariableChoice("string", self.parent)
    if self.cbVariable then
        table.insert(radioGroup, self.cbVariable)
    end
    
    --EXPRESSION
    self.cbExpression, self.btnExpression = SCEN_EDIT.AddExpression("string", self.parent)
    if self.cbExpression then
        table.insert(radioGroup, self.cbExpression)
    end
    SCEN_EDIT.MakeRadioButtonGroup(radioGroup)
end

function StringPanel:UpdateModel(field)
    if self.cbPredefinedString.checked then
        field.type = "pred"
        field.id = self.edString.text
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function StringPanel:UpdatePanel(field)  
    if field.type == "pred" then
        if not self.cbPredefinedString.checked then
            self.cbPredefinedString:Toggle()
        end
        self.edString.text = field.id
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
    elseif field.type == "expr" then
        if not self.cbExpression.checked then
            self.cbExpression:Toggle()
        end
        self.btnExpression.data = field.expr
    end
end
