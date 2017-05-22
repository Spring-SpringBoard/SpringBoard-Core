NumberPanel = AbstractTypePanel:extends{}

function NumberPanel:MakePredefinedOpt()
    local stackValuePanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined value: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackValuePanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.edValue = EditBox:New {
        text = "0",
        right = 1,
        width = 100,
        parent = stackValuePanel,
    }
end

function NumberPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and tonumber(self.edValue.text) ~= nil then
        field.type = "pred"
        field.id = tonumber(self.edValue.text)
        return true
    end
    return self:super('UpdateModel', field)
end

function NumberPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.edValue.text = tostring(field.id)
        return true
    end
    return self:super('UpdatePanel', field)
end
