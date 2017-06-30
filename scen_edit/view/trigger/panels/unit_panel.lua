UnitPanel = AbstractTypePanel:extends{}

function UnitPanel:MakePredefinedOpt()
    --PREDEFINED
    local stackUnitPanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined unit: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackUnitPanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.btnPredefined = Button:New {
        caption = '...',
        right = 40,
        width = 60,
        height = SB.conf.B_HEIGHT,
        parent = stackUnitPanel,
        unitID = nil,
    }
    self.OnSelectObject = function(objectID)
        self.unitID = objectID
        self.btnPredefined.caption = "ID=" .. objectID
        self.btnPredefined:Invalidate()
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
    end
    self.btnPredefined.OnClick = {
        function()
            SB.stateManager:SetState(SelectUnitState(self.OnSelectObject))
        end
    }
    self.btnPredefinedZoom = Button:New {
        caption = "",
        right = 1,
        width = SB.conf.B_HEIGHT,
        height = SB.conf.B_HEIGHT,
        parent = stackUnitPanel,
        tooltip = "Select unit",
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
                if self.unitID ~= nil then
                    local unitID = SB.model.unitManager:getSpringUnitID(self.unitID)
                    if unitID ~= nil and Spring.ValidUnitID(unitID) then
                        local x, y, z = Spring.GetUnitPosition(unitID)
                        Spring.SelectUnitArray({unitID})
                        Spring.SetCameraTarget(x, y, z)
                    end
                end
            end
        }
    }
end

function UnitPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.unitID ~= nil then
        field.type = "pred"
        field.value = self.unitID
        return true
    end
    return self:super('UpdateModel', field)
end

function UnitPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        self.OnSelectUnit(field.value)
        return true
    end
    return self:super('UpdatePanel', field)
end
