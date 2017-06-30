UnitTypePanel = AbstractTypePanel:extends{}

function UnitTypePanel:MakePredefinedOpt()
    local stackUnitTypePanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined type: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackUnitTypePanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.btnPredefined = Button:New {
        caption = '...',
        right = 1,
        width = 100,
        height = SB.conf.B_HEIGHT,
        parent = stackUnitTypePanel,
        unitTypeID = nil,
    }
    self.OnSelectObjectType = function(unitTypeID)
        self.unitTypeID = unitTypeID
        local defName = unitBridge.ObjectDefs[unitTypeID].name
        self.btnPredefined.caption = "ID=" .. defName
        self.btnPredefined:Invalidate()
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
    end
    self.btnPredefined.OnClick = {
        function()
            SB.stateManager:SetState(SelectUnitTypeState(self.OnSelectObjectType))
            --SB.SelectType(self.btnPredefined)
        end
    }
end

function UnitTypePanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.unitTypeID ~= nil then
        field.type = "pred"
        field.value = self.unitTypeID
        return true
    end
    return self:super('UpdateModel', field)
end

function UnitTypePanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.OnSelectObjectType(field.value)
        return true
    end
    return self:super('UpdatePanel', field)
end
