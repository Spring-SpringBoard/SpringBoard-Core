GenericArrayPanel = LCS.class{}

function GenericArrayPanel:init(parent, type)
    self.parent = parent
    self.type = type
    self.atomicType = type:gsub("_array", "")
    self.elements = {}
    self.subPanels = {}

    succ, msg = pcall(GenericArrayPanel.Initialize, self)
    if not succ then
        Spring.Echo(msg)
    end
end

function GenericArrayPanel:AddElement()
    self.subPanels:AddChild(Button:New {
        caption='Thingy!',
--        width='40%',
--        x = 1,
--        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick={
            function() 
                mode = 'add'
                Spring.Echo(screen0.classname)
                Spring.Echo(self.parent.parent.parent.classname)
                local newActionWindow = CustomWindow:New {
                    parent = screen0,
                    mode = mode,
                    dataType = self.atomicType,
                    parentWindow = self.parent.parent.parent,
                    parentObj = {},--btnExpressions.data,
--                    condition = btnExpressions.data[1], --nil if mode ~= 'edit'
--                    cbExpressions = cbExpressions,
                }
            end
        }
    })
end

function GenericArrayPanel:Initialize()
    Spring.Echo(self.atomicType)
    local radioGroup = {}
--    self.subPanels =  MakeComponentPanel(self.parent)--[[
    self.subPanels = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        parent = self.parent,
    }--]]

    local addPanel = MakeComponentPanel(self.parent)
    local btnAddElement = Button:New {
        caption='Add',
        width='40%',
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = addPanel,
        OnClick={function() self:AddElement() end}
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

function GenericArrayPanel:UpdateModel(field)
    if self.cbVariable and self.cbVariable.checked then
        field.type = "var"
        field.id = self.cmbVariable.variableIds[self.cmbVariable.selected]
    elseif self.cbExpression and self.cbExpression.checked then
        field.type = "expr"
        field.expr = self.btnExpression.data
    end
end

function GenericArrayPanel:UpdatePanel(field)
    if field.type == "var" then
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
