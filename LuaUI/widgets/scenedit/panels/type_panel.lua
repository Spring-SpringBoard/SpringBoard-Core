local Chili
Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26

TypePanel = {
}

function TypePanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function TypePanel:Initialize()
    local stackTypePanel = MakeComponentPanel(self.parent)
    self.cbPredefinedType = Chili.Checkbox:New {
        caption = "Predefined type: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackTypePanel,
    }
    self.btnPredefinedType = Chili.Button:New {
        caption = '...',
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackTypePanel,
        unitTypeId = nil,
    }
    self.btnPredefinedType.OnClick = {
        function() 
            SelectType(self.btnPredefinedType)
        end
    }
    self.btnPredefinedType.OnSelectUnitType = 
    function(unitTypeId)
        self.btnPredefinedType.unitTypeId = unitTypeId
        self.btnPredefinedType.caption = "Type id=" .. unitTypeId
        self.btnPredefinedType:Invalidate()
        if not self.cbPredefinedType.checked then 
            self.cbPredefinedType:Toggle()
        end
    end

    --SPECIAL TYPE, i.e TRIGGER
    local stackTypePanel = MakeComponentPanel(self.parent)
    self.cbSpecialType = Chili.Checkbox:New {
        caption = "Special type: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackTypePanel,
    }
    self.cmbSpecialType = ComboBox:New {
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackTypePanel,
        items = { "Trigger unit type" },
        OnSelectItem = {
            function(obj, itemIdx, selected)
                if selected and itemIdx > 0 then
                    if not self.cbSpecialType.checked then
                        self.cbSpecialType:Toggle()
                    end
                end
            end
        },
    }
    MakeRadioButtonGroup({self.cbSpecialType, self.cbPredefinedType})
end

function TypePanel:UpdateModel(unitType)
    if self.cbPredefinedType.checked then
        unitType.type = "predefined"
        unitType.id = self.btnPredefinedType.unitTypeId
    end
end

function TypePanel:UpdatePanel(unitType)
    if unitType.type == "predefined" then
        if not self.cbPredefinedType.checked then
            self.cbPredefinedType:Toggle()
        end
        self.btnPredefinedType.OnSelectUnitType(unitType.id)
    end
end
