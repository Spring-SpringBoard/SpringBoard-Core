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
        height = SB.conf.B_HEIGHT,
        parent = stackFeatureTypePanel,
        featureTypeID = nil,
    }
    self.OnSelectObjectType = function(featureTypeID)
        self.featureTypeID = featureTypeID
        local defName = featureBridge.ObjectDefs[featureTypeID].name
        self.btnPredefined.caption = "ID=" .. defName
        self.btnPredefined:Invalidate()
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
    end
    self.btnPredefined.OnClick = {
        function()
            SB.stateManager:SetState(SelectFeatureTypeState(self.OnSelectObjectType))
            --SB.SelectType(self.btnPredefined)
        end
    }
end

function FeatureTypePanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.featureTypeID ~= nil then
        field.type = "pred"
        field.value = self.featureTypeID
        return true
    end
    return self:super('UpdateModel', field)
end

function FeatureTypePanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.OnSelectObjectType(field.value)
        return true
    end
    return self:super('UpdatePanel', field)
end
