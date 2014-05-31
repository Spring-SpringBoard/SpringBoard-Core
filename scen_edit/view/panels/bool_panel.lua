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
        return true
    end
    return self:super('UpdateModel', field)
end

function BoolPanel:UpdatePanel(field)  
    if field.type == "pred" then
        if not self.cbPredefincbBool.checked then
            self.cbPredefincbBool:Toggle()
        end
        if field.bool ~= self.cbBool.checked then
            self.cbBool:Toggle()
        end
        return true
    end
    return self:super('UpdatePanel', field)
end
