BoolPanel = AbstractTypePanel:extends{}

function BoolPanel:init(...)
    self:super('init', 'bool', ...)
end

function BoolPanel:MakePredefinedOpt()
    local stackBoolPanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined bool: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackBoolPanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.cbBool = Checkbox:New {
        caption = "Value",
        checked = true,
        right = 1,
        width = 100,
        parent = stackBoolPanel,
    }
end

function BoolPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked then
        field.type = "pred"
        field.bool = self.cbBool.checked
        return true
    end
    return self:super('UpdateModel', field)
end

function BoolPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        if field.bool ~= self.cbBool.checked then
            self.cbBool:Toggle()
        end
        return true
    end
    return self:super('UpdatePanel', field)
end
