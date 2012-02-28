local Chili
Chili = WG.Chili
local C_HEIGHT = 16
local B_HEIGHT = 26

AreaPanel = {
}

function AreaPanel:New(obj)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    obj:Initialize()
    return obj
end

function AreaPanel:Initialize()
    local stackAreaPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedArea = Chili.Checkbox:New {
        caption = "Predefined area: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackAreaPanel,
    }
    self.btnPredefinedArea = Chili.Button:New {
        caption = '...',
        right = 1,
        width = 100,
        height = B_HEIGHT,
        parent = stackAreaPanel,
        areaId = nil,
    }
    self.btnPredefinedArea.OnClick = {
        function()
            SelectArea(self.btnPredefinedArea)
        end
    }
    self.btnPredefinedArea.OnSelectArea = {
        function(areaId) 
            self.btnPredefinedArea.areaId = areaId
            self.btnPredefinedArea.caption = "Area id=" .. areaId
            self.btnPredefinedArea:Invalidate()
            if not self.cbPredefinedArea.checked then 
                self.cbPredefinedArea:Toggle()
            end
        end
    }

    -- VARIABLE AREA
    self.cbVariableArea, self.cmbVariableArea = MakeVariableChoice(3, self.parent)
    if self.cbVariableArea then
        MakeRadioButtonGroup({self.cbPredefinedArea, self.cbVariableArea})
    end
end

function AreaPanel:UpdateModel(field)
    if self.cbPredefinedArea.checked then
        field.type = "predefined"
        field.id = self.btnPredefinedArea.areaId
    elseif self.cbVariableArea.checked then
        field.type = "variable"
        field.id = self.cmbVariableArea.variableIds[self.cmbVariableArea.selected]
    end
end

function AreaPanel:UpdatePanel(field)
    if field.type == "predefined" then
        if not self.cbPredefinedArea.checked then
            self.cbPredefinedArea:Toggle()
        end
        CallListeners(self.btnPredefinedArea.OnSelectArea, field.id)
    elseif field.type == "variable" then
        if not self.cbVariableArea.checked then
            self.cbVariableArea:Toggle()
        end
        for i = 1, #self.cmbVariableArea.variableIds do
            local variableId = self.cmbVariableArea.variableIds[i]
            if variableId == field.id then
                self.cmbVariableArea:Select(i)
                break
            end
        end
    end
end
