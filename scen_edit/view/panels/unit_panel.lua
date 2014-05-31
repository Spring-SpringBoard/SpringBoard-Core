UnitPanel = AbstractTypePanel:extends{}

function UnitPanel:init(parent, sources)
    self:super('init', 'unit', parent, sources)
end

function UnitPanel:MakePredefinedOpt()
    --PREDEFINED
    local stackUnitPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedUnit = Checkbox:New {
        caption = "Predefined unit: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackUnitPanel,
    }
    table.insert(self.radioGroup, self.cbPredefinedUnit)
    self.btnPredefinedUnit = Button:New {
        caption = '...',
        right = 40,
        width = 60,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackUnitPanel,
        unitId = nil,
    }
    self.btnPredefinedUnit.OnClick = {
        function()
            SCEN_EDIT.stateManager:SetState(SelectUnitState(self.btnPredefinedUnit))
        end
    }
    self.btnPredefinedUnit.OnSelectUnit = {
        function(unitId)
            self.btnPredefinedUnit.unitId = unitId
            self.btnPredefinedUnit.caption = "Id=" .. unitId
            self.btnPredefinedUnit:Invalidate()
            if not self.cbPredefinedUnit.checked then 
                self.cbPredefinedUnit:Toggle()
            end
        end
    }
    self.btnPredefinedUnitZoom = Button:New {
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
                if self.btnPredefinedUnit.unitId ~= nil then
                    local unitId = SCEN_EDIT.model.unitManager:getSpringUnitId(self.btnPredefinedUnit.unitId)
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

function UnitPanel:MakeSpecialOpt()
    --SPECIAL UNIT, i.e TRIGGER
    local stackUnitPanel = MakeComponentPanel(self.parent)
    self.cbSpecialUnit = Checkbox:New {
        caption = "Special unit: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackUnitPanel,
    }
    table.insert(self.radioGroup, self.cbSpecialUnit)
    self.cmbSpecialUnit = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackUnitPanel,
        items = { "Trigger unit" },
    }
    self.cmbSpecialUnit.OnSelect = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                if not self.cbSpecialUnit.checked then
                    self.cbSpecialUnit:Toggle()
                end
            end
        end
    }
end

function UnitPanel:UpdateModel(field)
    if self.cbPredefinedUnit and self.cbPredefinedUnit.checked and self.btnPredefinedUnit.unitId ~= nil then
        field.type = "pred"
        field.id = self.btnPredefinedUnit.unitId
        return true
    elseif self.cbSpecialUnit and self.cbSpecialUnit.checked then
        field.type = "spec"
        field.name = self.cmbSpecialUnit.items[self.cmbSpecialUnit.selected]
        return true
    end
    return self:super('UpdateModel', field)
end

function UnitPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedUnit.checked then
            self.cbPredefinedUnit:Toggle()
        end
        CallListeners(self.btnPredefinedUnit.OnSelectUnit, field.id)
        return true
    elseif field.type == "spec" then
        if not self.cbSpecialUnit.checked then
            self.cbSpecialUnit:Toggle()
        end
        self.cmbSpecialUnit:Select(1) --TODO:fix it
        return true
    end
    return self:super('UpdatePanel', field)
end
