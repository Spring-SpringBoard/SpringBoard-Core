NumberPanel = {
}

function NumberPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function NumberPanel:Initialize()
    local radioGroup = {}
    local stackValuePanel = MakeComponentPanel(self.parent)
    self.cbPredefinedValue = Checkbox:New {
        caption = "Predefined value: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackValuePanel,
    }    
    table.insert(radioGroup, self.cbPredefinedValue)
    self.edValue = EditBox:New {
        text = "0",
        right = 1,
        width = 100,
        parent = stackValuePanel,
    }
    
    --VARIABLE
    self.cbVariable, self.cmbVariable = MakeVariableChoice("number", self.parent)
    if self.cbVariable then
        table.insert(radioGroup, self.cbVariable)
    end
    
    --EXPRESSION
    self.cbExpression, self.btnExpression = SCEN_EDIT.AddExpression("number", self.parent)
    if self.cbExpression then
        table.insert(radioGroup, self.cbExpression)
    end
    SCEN_EDIT.MakeRadioButtonGroup(radioGroup)
end

function NumberPanel:UpdateModel(field)
    if self.cbPredefinedValue.checked then
        field.type = "pred"
        field.id = tonumber(self.edValue.text) or 0
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function NumberPanel:UpdatePanel(field)  
    if field.type == "pred" then
        if not self.cbPredefinedValue.checked then
            self.cbPredefinedValue:Toggle()
        end
        self.edValue.text = tostring(field.id)
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
