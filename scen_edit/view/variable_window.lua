VariableWindow = LCS.class{}

function VariableWindow:init(variable)
    self.variable = variable

    local btnOk = Button:New {
        caption='OK',
        width='40%',
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_OK_COLOR,
    }
    local btnCancel = Button:New {
        caption='Cancel',
        width='40%',
        x = '50%',
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_CANCEL_COLOR,
        OnClick={function() self.window:Dispose() end}
    }

    local lblName = Label:New {
        caption = "Name:",
        width = 50,
        x = 1,
        y = 15,
    }
    self.edValue = EditBox:New {
        text = self.variable.name,
        x = 60,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        y = 10
    }

    local lblType = Label:New {
        caption = "Type:",
        width = 50,
        x = 1,
        y = 50,
    }


    self.variablePanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        y = 20,
        x = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0}
    }

    self.cmbType = ComboBox:New {
        x = 60,
        width = 100,
        y = 50,
        height = SCEN_EDIT.conf.B_HEIGHT,
        items = SCEN_EDIT.metaModel.variableTypes,
        parent = stackTypePanel,
        OnSelect = {
            function(object, itemIdx, selected)    
                if selected and itemIdx > 0 then
                    self.variablePanel:ClearChildren()
            
                    local typeId = itemIdx
                    local inputType = SCEN_EDIT.metaModel.variableTypes[typeId] 
                    local subPanel = SCEN_EDIT.createNewPanel(inputType, self.variablePanel, "pred")
                    if subPanel then
                        self.variablePanel[inputType] = subPanel
                        SCEN_EDIT.MakeSeparator(self.variablePanel)
                    end
                end
            end
        },
    }

    self.cmbType:Select(-1)
    self.cmbType:Select(GetIndex(SCEN_EDIT.metaModel.variableTypes, self.variable.type))

    self.window = Window:New {
        width = 340,
        height = 450,
        minimumSize = {150,200},
        x = 500,
        y = 300,
        parent = screen0,
        children = {
            ScrollPanel:New {
                x = 1,
                y = 90,
                bottom = 2 * SCEN_EDIT.conf.C_HEIGHT,
                right = 5,
                parent = self.window,
                children = {
                    self.variablePanel,
                },
            },
            btnOk,
            btnCancel,
            lblName,
            self.edValue,
            lblType,
            self.cmbType,
        }
    }

    SCEN_EDIT.MakeConfirmButton(self.window, btnOk)
end

function VariableWindow:UpdatePanel(variable)
    self.edValue.text = variable.name
    self.variable = variable
    local varType = variable.type
    self.variablePanel[varType]:UpdatePanel(variable.value)   
end

function VariableWindow:UpdateModel(variable)
    variable.name = self.edValue.text
    local newVariableType = self.cmbType.items[self.cmbType.selected]
    local typeChanged = false
    if variable.type ~= newVarType then
        typeChanged = true
    end
    variable.type = newVariableType
    variable.value = {}
    self.variablePanel[variable.type]:UpdateModel(self.variable.value)
    
--[[    if typeChanged then
        SCEN_EDIT.model:RemoveVariable(variable.id)
        newVariable = SCEN_EDIT.model:NewVariable(variable.type)
        newVariable.value = variable.value
        newVariable.name = variable.name
    end--]]
end
