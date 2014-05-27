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
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function TeamPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedTeam.checked then
            self.cbPredefinedTeam:Toggle()
        end
        self.cmbPredefinedTeam:Select(GetIndex(self.cmbPredefinedTeam.playerTeamIds, field.id))
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
