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
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackUnitPanel,
        unitId = nil,
    }
    self.btnPredefined.OnClick = {
        function()
            SCEN_EDIT.stateManager:SetState(SelectUnitState(self.btnPredefined))
        end
    }
    self.btnPredefined.OnSelectObject = {
        function(objectID)
            self.btnPredefined.unitId = objectID
            self.btnPredefined.caption = "Id=" .. objectID
            self.btnPredefined:Invalidate()
            if not self.cbPredefined.checked then
                self.cbPredefined:Toggle()
            end
        end
    }
    self.btnPredefinedZoom = Button:New {
        caption = "",
        right = 1,
        width = SCEN_EDIT.conf.B_HEIGHT,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackUnitPanel,
        padding = {0, 0, 0, 0},
        children = {
            Image:New {
                tooltip = "Select unit",
                file=SCEN_EDIT_IMG_DIR .. "search.png",
                height = SCEN_EDIT.conf.B_HEIGHT,
                width = SCEN_EDIT.conf.B_HEIGHT,
                padding = {0, 0, 0, 0},
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function()
                if self.btnPredefined.unitId ~= nil then
                    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.btnPredefined.unitId)
                    if unitId ~= nil and Spring.ValidUnitID(unitId) then
                        local x, y, z = Spring.GetUnitPosition(unitId)
                        Spring.SelectUnitArray({unitId})
                        Spring.SetCameraTarget(x, y, z)
                    end
                end
            end
        }
    }
end

function UnitPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.btnPredefined.unitId ~= nil then
        field.type = "pred"
        field.id = self.btnPredefined.unitId
        return true
    end
    return self:super('UpdateModel', field)
end

function UnitPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        CallListeners(self.btnPredefined.OnSelectUnit, field.id)
        return true
    end
    return self:super('UpdatePanel', field)
end
