FeaturePanel = AbstractTypePanel:extends{}

function FeaturePanel:MakePredefinedOpt()
    --PREDEFINED
    local stackFeaturePanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined feature: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackFeaturePanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.btnPredefined = Button:New {
        caption = '...',
        right = 40,
        width = 60,
        height = SB.conf.B_HEIGHT,
        parent = stackFeaturePanel,
        featureID = nil,
    }
    self.OnSelectObject = function(objectID)
        self.btnPredefined.featureID = objectID
        self.btnPredefined.caption = "ID=" .. objectID
        self.btnPredefined:Invalidate()
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
    end
    self.btnPredefined.OnClick = {
        function()
            SB.stateManager:SetState(SelectFeatureState(self.OnSelectObject))
        end
    }
    self.btnPredefinedZoom = Button:New {
        caption = "",
        right = 1,
        width = SB.conf.B_HEIGHT,
        height = SB.conf.B_HEIGHT,
        parent = stackFeaturePanel,
        tooltip = "Select feature",
        padding = {2, 2, 2, 2},
        children = {
            Image:New {
                file = SB_IMG_DIR .. "position-marker.png",
                height = "100%",
                width = "100%",
            },
        },
        OnClick = {
            function()
                if self.btnPredefined.featureID ~= nil then
                    local featureID = SB.model.featureManager:getSpringFeatureID(self.btnPredefined.featureID)
                    if featureID ~= nil and Spring.ValidFeatureID(featureID) then
                        local x, y, z = Spring.GetFeaturePosition(featureID)
                        SB.view.selectionManager:Select({
                            features = {featureID}
                        })
                        Spring.SetCameraTarget(x, y, z)
                    end
                end
            end
        }
    }
end

function FeaturePanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.btnPredefined.featureID ~= nil then
        field.type = "pred"
        field.value = self.btnPredefined.featureID
        return true
    end
    return self:super('UpdateModel', field)
end

function FeaturePanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.OnSelectFeature(field.value)
        return true
    end
    return self:super('UpdatePanel', field)
end
