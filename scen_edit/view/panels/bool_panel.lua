BoolPanel = AbstractTypePanel:extends{}

function BoolPanel:init(parent, sources)
    self:super('init', 'bool', parent, sources)
end

function BoolPanel:MakePredefinedOpt()
    local stackBoolPanel = MakeComponentPanel(self.parent)
    self.cbPredefincbBool = Checkbox:New {
        caption = "Predefined bool: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackBoolPanel,
    }    
    table.insert(self.radioGroup, self.cbPredefincbBool)
    self.cbBool = Checkbox:New {
        caption = "Value",
        checked = true,
        right = 1,
        width = 100,
        parent = stackBoolPanel,
    }
end

function BoolPanel:UpdateModel(field)
    if self.cbPredefinedBool and self.cbPredefincbBool.checked then
        field.type = "pred"
        field.bool = self.cbBool.checked
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function BoolPanel:UpdatePanel(field)  
    if field.type == "pred" then
        if not self.cbPredefincbBool.checked then
            self.cbPredefincbBool:Toggle()
        end
        if field.bool ~= self.cbBool.checked then
            self.cbBool:Toggle()
        end
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
