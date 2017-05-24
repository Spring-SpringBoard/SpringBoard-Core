FeatureTypePanel = AbstractTypePanel:extends{}

function FeatureTypePanel:MakePredefinedOpt()
    local stackFeatureTypePanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined type: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackFeatureTypePanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.btnPredefined = Button:New {
        caption = '...',
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackFeatureTypePanel,
        featureTypeId = nil,
    }
    self.btnPredefined.OnClick = {
        function()
            SCEN_EDIT.stateManager:SetState(SelectFeatureTypeState(self.btnPredefined))
            --SCEN_EDIT.SelectType(self.btnPredefined)
        end
    }
    self.btnPredefined.OnSelectObjectType = {
        function(featureTypeId)
            self.btnPredefined.featureTypeId = featureTypeId
            local defName = featureBridge.ObjectDefs[featureTypeId].name
            self.btnPredefined.caption = "Id=" .. defName
            self.btnPredefined:Invalidate()
            if not self.cbPredefined.checked then
                self.cbPredefined:Toggle()
            end
        end
    }
end

function FeatureTypePanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.btnPredefined.featureTypeId ~= nil then
        field.type = "pred"
        field.value = self.btnPredefined.featureTypeId
        return true
    end
    return self:super('UpdateModel', field)
end

function FeatureTypePanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.btnPredefined.OnSelectObjectType[1](field.value)
        return true
    end
    return self:super('UpdatePanel', field)
end
