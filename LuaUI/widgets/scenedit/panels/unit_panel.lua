local Chili
Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26

UnitPanel = {
}

function UnitPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function UnitPanel:Initialize()
    --PREDEFINED
    local stackUnitPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedUnit = Chili.Checkbox:New {
        caption = "Predefined unit: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackUnitPanel,
    }
    self.btnPredefinedUnit = Chili.Button:New {
        caption = '...',
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackUnitPanel,
        unitId = nil,
    }
    self.btnPredefinedUnit.OnClick = {
        function()
            SelectUnit(self.btnPredefinedUnit)
        end
    }
    self.btnPredefinedUnit.OnSelectUnit = {
        function(unitId)
            self.btnPredefinedUnit.unitId = unitId
            self.btnPredefinedUnit.caption = "Unit id=" .. unitId
            self.btnPredefinedUnit:Invalidate()
            if not self.cbPredefinedUnit.checked then 
                self.cbPredefinedUnit:Toggle()
            end
        end
    }
    --SPECIAL UNIT, i.e TRIGGER
    local stackUnitPanel = MakeComponentPanel(self.parent)
    self.cbSpecialUnit = Chili.Checkbox:New {
        caption = "Special unit: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackUnitPanel,
    }
    self.cmbSpecialUnit = ComboBox:New {
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackUnitPanel,
        items = { "Trigger unit" },
    }
    self.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                if not self.cbSpecialUnit.checked then
                    self.cbSpecialUnit:Toggle()
                end
            end
        end
    }

    -- VARIABLE UNIT
    self.cbVariableUnit, self.cmbVariableUnit = MakeVariableChoice(1, self.parent)
    if self.cbVariableUnit then
        MakeRadioButtonGroup({self.cbSpecialUnit, self.cbPredefinedUnit,
          self.cbVariableUnit})
    else
        MakeRadioButtonGroup({self.cbSpecialUnit, self.cbPredefinedUnit})
    end
end

function UnitPanel:UpdateModel(field)
    if self.cbPredefinedUnit.checked then
        field.type = "predefined"
        field.id = self.btnPredefinedUnit.unitId
    elseif self.cbSpecialUnit.checked then
        field.type = "special"
        field.name = self.cmbSpecialUnit.items[self.cmbSpecialUnit.selected]
    elseif self.cbVariableUnit.checked then
        field.type = "variable"
        field.id = self.cmbVariableUnit.variableIds[self.cmbVariableUnit.selected]
    end
end

function UnitPanel:UpdatePanel(field)
    if field.type == "predefined" then
        if not self.cbPredefinedUnit.checked then
            self.cbPredefinedUnit:Toggle()
        end
        CallListeners(self.btnPredefinedUnit.OnSelectUnit, field.id)
    elseif field.type == "special" then
        if not self.cbSpecialUnit.checked then
            self.cbSpecialUnit:Toggle()
        end
        self.cmbSpecialUnit:Select(1) --TODO:fix it
    elseif field.type == "variable" then
        if not self.cbVariableUnit.checked then
            self.cbVariableUnit:Toggle()
        end
        for i = 1, #self.cmbVariableUnit.variableIds do
            local variableId = self.cmbVariableUnit.variableIds[i]
            if variableId == field.id then
                self.cmbVariableUnit:Select(i)
                break
            end
        end
    end
end
