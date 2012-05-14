local Chili = WG.Chili
local model = SCEN_EDIT.model

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
	local radioGroup = {}
    local stackAreaPanel = MakeComponentPanel(self.parent)
    self.cbPredefinedArea = Chili.Checkbox:New {
        caption = "Predefined area: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackAreaPanel,
    }
	table.insert(radioGroup, self.cbPredefinedArea)
    self.btnPredefinedArea = Chili.Button:New {
        caption = '...',
        right = 1,
        width = 100,
        height = model.B_HEIGHT,
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
	--SPECIAL AREA, i.e TRIGGER
    local stackAreaPanel = MakeComponentPanel(self.parent)
    self.cbSpecialArea = Chili.Checkbox:New {
        caption = "Special area: ",
        right = 100 + 10,
        x = 1,
        checked = true,
        parent = stackAreaPanel,
    }
	table.insert(radioGroup, self.cbSpecialArea)
    self.cmbSpecialArea = ComboBox:New {
        right = 1,
        width = 100,
        height = model.B_HEIGHT,
        parent = stackAreaPanel,
        items = { "Trigger area" },
    }
    self.cmbSpecialArea.OnSelectItem = {
        function(obj, itemIdx, selected)
            if selected and itemIdx > 0 then
                if not self.cbSpecialArea.checked then
                    self.cbSpecialArea:Toggle()
                end
            end
        end
    }

   --VARIABLE
    self.cbVariable, self.cmbVariable = MakeVariableChoice("area", self.parent)
    if self.cbVariable then
		table.insert(radioGroup, self.cbVariable)
    end
	
	--EXPRESSION
	self.cbExpression, self.btnExpression = SCEN_EDIT.AddExpression("area", self.parent)
	if self.cbExpression then
		table.insert(radioGroup, self.cbExpression)
	end
	MakeRadioButtonGroup(radioGroup)
end

function AreaPanel:UpdateModel(field)
    if self.cbPredefinedArea.checked then
        field.type = "pred"
        field.id = self.btnPredefinedArea.areaId
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function AreaPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedArea.checked then
            self.cbPredefinedArea:Toggle()
        end
        CallListeners(self.btnPredefinedArea.OnSelectArea, field.id)
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
