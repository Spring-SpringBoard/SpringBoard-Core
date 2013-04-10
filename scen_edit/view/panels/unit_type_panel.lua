UnitTypePanel = {
}

function UnitTypePanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function UnitTypePanel:Initialize()
    local radioGroup = {}
    local stackUnitTypePanel = MakeComponentPanel(self.parent)
    self.cbPredefinedType = Checkbox:New {
        caption = "Predefined type: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackUnitTypePanel,
    }
    table.insert(radioGroup, self.cbPredefinedType)
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
            self.btnPredefinedType.caption = "Type id=" .. unitTypeId
            self.btnPredefinedType:Invalidate()
            if not self.cbPredefinedType.checked then 
                self.cbPredefinedType:Toggle()
            end
        end
    }
    
    --SPECIAL TYPE, i.e TRIGGER
    local stackUnitTypePanel = MakeComponentPanel(self.parent)
    self.cbSpecialType = Checkbox:New {
        caption = "Special type: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackUnitTypePanel,
    }
    table.insert(radioGroup, self.cbSpecialType)
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
    
    --VARIABLE
    self.cbVariable, self.cmbVariable = MakeVariableChoice("unitType", self.parent)
    if self.cbVariable then
        table.insert(radioGroup, self.cbVariable)
    end
    
    self.cbExpression, self.btnExpression = SCEN_EDIT.AddExpression("unitType", self.parent)
    if self.cbExpression then
        table.insert(radioGroup, self.cbExpression)
    end
    SCEN_EDIT.MakeRadioButtonGroup(radioGroup)
end

function UnitTypePanel:UpdateModel(field)
    if self.cbPredefinedType.checked then
        field.type = "pred"
        field.id = self.btnPredefinedType.unitTypeId
    elseif self.cbSpecialType.checked then
        field.type = "spec"
        field.name = self.cmbSpecialType.items[self.cmbSpecialType.selected]
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function UnitTypePanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedType.checked then
            self.cbPredefinedType:Toggle()
        end
        self.btnPredefinedType.OnSelectUnitType[1](field.id)
    elseif field.type == "spec" then
        if not self.cbSpecialType.checked then
            self.cbSpecialType:Toggle()
        end
        self.cmbSpecialType:Select(1) --TODO:fix it        
    elseif field.type == "var" then
        if not self.cbVariable.checked then
            self.cbVariable:Toggle()
        end
        for i = 1, #self.cmbVariable.variableIds do
            local variableId = self.cmbVariable.variableIds[i]
            if variableId == field.id then
                self.cmbVariable:Select(i)
                break
            end
        end
    elseif field.type == "expr" then
        if not self.cbExpression.checked then
            self.cbExpression:Toggle()
        end
        self.btnExpression.data = field.expr
    end
end
