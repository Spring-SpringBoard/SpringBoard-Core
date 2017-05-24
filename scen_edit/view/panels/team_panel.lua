TeamPanel = AbstractTypePanel:extends{}

function TeamPanel:MakePredefinedOpt()
    local stackTeamPanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined team: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackTeamPanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.cmbPredefined = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackTeamPanel,
        items = GetField(SCEN_EDIT.model.teamManager:getAllTeams(), "name"),
        playerTeamIds = GetField(SCEN_EDIT.model.teamManager:getAllTeams(), "id"),
    }
end

function TeamPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked then
        field.type = "pred"
        field.value = self.cmbPredefined.playerTeamIds[self.cmbPredefined.selected]
        return true
    end
    return self:super('UpdateModel', field)
end

function TeamPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.cmbPredefined:Select(GetIndex(self.cmbPredefined.playerTeamIds, field.value))
        return true
    end
    return self:super('UpdatePanel', field)
end
