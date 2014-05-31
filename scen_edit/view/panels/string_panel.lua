StringPanel = AbstractTypePanel:extends{}

function StringPanel:init(parent, sources)
    self:super('init', 'string', parent, sources)
end

function StringPanel:MakePredefinedOpt()
    local stackStringPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedString = Checkbox:New {
        caption = "Predefined string: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackStringPanel,
    }    
    table.insert(self.radioGroup, self.cbPredefinedString)
    self.edString = EditBox:New {
        text = "text",
        right = 1,
        width = 100,
        parent = stackStringPanel,
    }
end

function StringPanel:UpdateModel(field)
    if self.cbPredefinedString and self.cbPredefinedString.checked then
        field.type = "pred"
        field.id = self.edString.text
        return true
    end
    return self:super('UpdateModel', field)
end

function StringPanel:UpdatePanel(field)  
    if field.type == "pred" then
        if not self.cbPredefinedString.checked then
            self.cbPredefinedString:Toggle()
        end
        self.edString.text = field.id
        return true
    end
    return self:super('UpdatePanel', field)
end
