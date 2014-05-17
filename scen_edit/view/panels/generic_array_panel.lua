GenericArrayPanel = LCS.class{}

function GenericArrayPanel:init(parent, type)
    self.parent = parent
    self.type = type
    self.atomicType = type:gsub("_array", "")
    self.elements = {}
    self.subPanels = {}

    self:Initialize()
end

function GenericArrayPanel:Initialize()
    local radioGroup = {}
    self.subPanels = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        parent = self.parent,
    }

    local addPanel = MakeComponentPanel(self.parent)

    self.cbPredefinedArray = Checkbox:New {
        caption = "Predefined array: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = addPanel,
    }
    table.insert(radioGroup, self.cbPredefinedArray)
    self.btnAddElement = Button:New {
        caption = '+',
        right = 40,
        width = 60,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = addPanel,
        OnClick= {
            function() 
                self:AddElement() 
                if not self.cbPredefinedArray.checked then 
                    self.cbPredefinedArray:Toggle()
                end
            end
        }
    }
    
    --VARIABLE
    self.cbVariable, self.cmbVariable = MakeVariableChoice(self.type, self.parent)
    if self.cbVariable then
        table.insert(radioGroup, self.cbVariable)
    end
    
    self.cbExpression, self.btnExpression = SCEN_EDIT.AddExpression(self.type, self.parent)
    if self.cbExpression then
        table.insert(radioGroup, self.cbExpression)
    end
    SCEN_EDIT.MakeRadioButtonGroup(radioGroup)
end

function GenericArrayPanel:AddElement()
	local subPanel = SCEN_EDIT.createNewPanel(self.atomicType, self.subPanels)
    table.insert(self.elements, subPanel)
	SCEN_EDIT.MakeSeparator(self.subPanels)
end

function GenericArrayPanel:UpdateModel(field)
    if self.cbPredefinedArray.checked then
        field.type = "pred"
        field.id = {}
        for _, subPanel in pairs(self.elements) do
            local subPanelValue = {}
            subPanel:UpdateModel(subPanelValue)
            table.insert(field.id, subPanelValue)
        end
    elseif self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function GenericArrayPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefinedArray.checked then
            self.cbPredefinedArray:Toggle()
        end
        for i, data in pairs(field.id) do
            self:AddElement()
            self.elements[i]:UpdatePanel(data)
        end
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
