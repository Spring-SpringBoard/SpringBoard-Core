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
        unitId = nil,
    }
    self.OnSelectObject = function(objectID)
        self.btnPredefined.unitId = objectID
        self.btnPredefined.caption = "Id=" .. objectID
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
        padding = {0, 0, 0, 0},
        children = {
            Image:New {
                tooltip = "Select unit",
                file=SB_IMG_DIR .. "search.png",
                height = SB.conf.B_HEIGHT,
                width = SB.conf.B_HEIGHT,
                padding = {0, 0, 0, 0},
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function()
                if self.btnPredefined.unitId ~= nil then
                    local unitId = SB.model.unitManager:getSpringUnitId(self.btnPredefined.unitId)
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
        field.value = self.btnPredefined.unitId
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
