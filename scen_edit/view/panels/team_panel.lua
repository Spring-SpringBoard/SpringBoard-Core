TeamPanel = AbstractTypePanel:extends{}

function TeamPanel:init(parent, sources)
    self:super('init', 'team', parent, sources)
end

function TeamPanel:MakePredefinedOpt()
    local stackTeamPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedTeam = Checkbox:New {
        caption = "Predefined team: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackTeamPanel,
    }
    table.insert(self.radioGroup, self.cbPredefinedTeam)
    self.cmbPredefinedTeam = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackTeamPanel,
        items = GetField(SCEN_EDIT.model.teams, "name"),
        playerTeamIds = GetField(SCEN_EDIT.model.teams, "id"),
    }
end

function TeamPanel:UpdateModel(field)
    if self.cbPredefinedTeam and self.cbPredefinedTeam.checked then
        field.type = "pred"
        field.id = self.cmbPredefinedTeam.playerTeamIds[self.cmbPredefinedTeam.selected]
        return true
    end
    return self:super('UpdateModel', field)
end

function TeamPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedTeam.checked then
            self.cbPredefinedTeam:Toggle()
        end
        self.cmbPredefinedTeam:Select(GetIndex(self.cmbPredefinedTeam.playerTeamIds, field.id))
        return true
    end
    return self:super('UpdatePanel', field)
end
