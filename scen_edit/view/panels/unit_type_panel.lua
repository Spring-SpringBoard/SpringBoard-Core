UnitTypePanel = AbstractTypePanel:extends{}

function UnitTypePanel:init(parent, sources)
    self:super('init', 'unitType', parent, sources)
end

function UnitTypePanel:MakePredefinedOpt()
    local stackUnitTypePanel = MakeComponentPanel(self.parent)
    self.cbPredefinedType = Checkbox:New {
        caption = "Predefined type: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackUnitTypePanel,
    }
    table.insert(self.radioGroup, self.cbPredefinedType)
    self.btnPredefinedType = Button:New {
        caption = '...',
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackUnitTypePanel,
        unitTypeId = nil,
    }
    self.btnPredefinedType.OnClick = {
        function() 
            SCEN_EDIT.stateManager:SetState(SelectUnitTypeState(self.btnPredefinedType))
            --SCEN_EDIT.SelectType(self.btnPredefinedType)
        end
    }
    self.btnPredefinedType.OnSelectUnitType = {
        function(unitTypeId)
            self.btnPredefinedType.unitTypeId = unitTypeId
            self.btnPredefinedType.caption = "Id=" .. unitTypeId
            self.btnPredefinedType:Invalidate()
            if not self.cbPredefinedType.checked then 
                self.cbPredefinedType:Toggle()
            end
        end
    }
end

function UnitTypePanel:MakeSpecialOpt()
    --SPECIAL TYPE, i.e TRIGGER
    local stackUnitTypePanel = MakeComponentPanel(self.parent)
    self.cbSpecialType = Checkbox:New {
        caption = "Special type: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackUnitTypePanel,
    }
    table.insert(self.radioGroup, self.cbSpecialType)
    self.cmbSpecialType = ComboBox:New {
        right = 1,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackUnitTypePanel,
        items = { "Trigger unit type" },
        OnSelect = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    if not self.cbSpecialType.checked then
                        self.cbSpecialType:Toggle()
                    end
                end
            end
        },
    }
end

function UnitTypePanel:UpdateModel(field)
    if self.cbPredefinedType and self.cbPredefinedType.checked and self.btnPredefinedType.unitTypeId ~= nil then
        field.type = "pred"
        field.id = self.btnPredefinedType.unitTypeId
        return true
    elseif self.cbSpecialType and self.cbSpecialType.checked then
        field.type = "spec"
        field.name = self.cmbSpecialType.items[self.cmbSpecialType.selected]
        return true
    end
    return self:super('UpdateModel', field)
end

function UnitTypePanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedType.checked then
            self.cbPredefinedType:Toggle()
        end
        self.btnPredefinedType.OnSelectUnitType[1](field.id)
        return true
    elseif field.type == "spec" then
        if not self.cbSpecialType.checked then
            self.cbSpecialType:Toggle()
        end
        self.cmbSpecialType:Select(1) --TODO:fix it        
        return true
    end
    return self:super('UpdatePanel', field)
end
