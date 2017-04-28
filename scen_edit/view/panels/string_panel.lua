StringPanel = AbstractTypePanel:extends{}

function StringPanel:init(...)
    self:super('init', 'string', ...)
end

function StringPanel:MakePredefinedOpt()
    local stackStringPanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined string: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackStringPanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.edString = EditBox:New {
        text = "text",
        right = 1,
        width = 100,
        parent = stackStringPanel,
    }
end

function StringPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked then
        field.type = "pred"
        field.id = self.edString.text
        return true
    end
    return self:super('UpdateModel', field)
end

function StringPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.edString.text = field.id
        return true
    end
    return self:super('UpdatePanel', field)
end
