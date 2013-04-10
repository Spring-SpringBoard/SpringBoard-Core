VariableSettingsWindow = Window:Inherit {
    classname = "window",
    clientWidth = 300,
    clientHeight = 250,
    minimumSize = {150,200},
    x = 500,
    y = 300,
}

local this = VariableSettingsWindow
local inherited = this.inherited

function VariableSettingsWindow:New(obj)
    local btnAddVariable = Button:New {
        caption='Add variable',
        width='40%',
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick={ 
            function()                 
                obj:AddVariable()
            end}
    }
    local btnClose = Button:New {
        caption='Close',
        width='40%',
        x = '50%',
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
    }
    obj.variablesPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    obj.children = {
        ScrollPanel:New {
            x = 1,
            y = 15,
            right = 5,
            bottom = SCEN_EDIT.conf.C_HEIGHT * 2,
            children = { 
                obj.variablesPanel
            },
        },
        btnAddVariable,
        btnClose,
    }
    btnClose.OnClick={
        function() 
            obj:Dispose() 
        end
    }
    obj = inherited.New(self, obj)
    obj:Populate()
    local variableManagerListener = VariableManagerListenerWidget(obj)
    SCEN_EDIT.model.variableManager:addListener(variableManagerListener)
    return obj
end

function VariableSettingsWindow:AddVariable()
    local variable = {
        type = "number",
        value = {},
        name = "new variable",
    }
    success, msg = pcall(VariableSettingsWindow.MakeVariableWindow, self, variable, false)
    if not success then
        Spring.Echo(msg)
    end
--[[    local newVariable = SCEN_EDIT.model:NewVariable("number")
    self:Populate()
    for i = 1, #self.variablesPanel.children do
        local panel = self.variablesPanel.children[i]
        if panel.variableId == newVariable.id then
            local btnEdit = panel.children[1]
            btnEdit:CallListeners(btnEdit.OnClick)
            break
        end
    end-]]
end

function VariableSettingsWindow:MakeRemoveVariableWindow(variableId)
    local cmd = RemoveVariableCommand(variableId)
    SCEN_EDIT.commandManager:execute(cmd)
end

function VariableSettingsWindow:Populate()
    self.variablesPanel:ClearChildren()
    local variables = SCEN_EDIT.model.variableManager:getAllVariables()
    for i = 1, #variables do
        local variable = variables[i]
        local variableStackPanel = MakeComponentPanel(self.variablesPanel)
        variableStackPanel.variableId = variable.id
        local btnEditVariable = Button:New {
            caption = variable.name,
            right = SCEN_EDIT.conf.B_HEIGHT + 10,
            x = 1,
            height = SCEN_EDIT.conf.B_HEIGHT,
            _toggle = nil,
            parent = variableStackPanel,
        }
        local btnRemoveVariable = Button:New {
            caption = "",
            right = 1,
            width = SCEN_EDIT.conf.B_HEIGHT,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = variableStackPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New { 
                    tooltip = "Remove variable", 
                    file=SCEN_EDIT_IMG_DIR .. "list-remove.png", 
                    height = SCEN_EDIT.conf.B_HEIGHT, 
                    width = SCEN_EDIT.conf.B_HEIGHT,
                    padding = {0, 0, 0, 0},
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {function() self:MakeRemoveVariableWindow(variable.id) end},
        }
            
        btnEditVariable.OnClick = {
            function() 
                local newWin = self:MakeVariableWindow(variable, true)
            end
        }
    end
end

function VariableSettingsWindow:MakeVariableWindow(variable, edit)
    local newWin = VariableWindow:New {
        parent = self.parent,
        variable = variable,
    }
    table.insert(newWin.OnConfirm,
        function()
            newWin:UpdateModel(variable)
            local cmd = nil
            if edit then
                cmd = UpdateVariableCommand(variable)
            else
                cmd = AddVariableCommand(variable)
            end
            SCEN_EDIT.commandManager:execute(cmd)
        end
    )
    newWin:UpdatePanel(variable)
    if self.x + self.width + newWin.width > self.parent.width then
        newWin.x = self.x - newWin.width
    else
        newWin.x = self.x + self.width
    end
    newWin.y = self.y

    self.disableChildrenHitTest = true
    table.insert(newWin.OnDispose, 
        function() 
            self.disableChildrenHitTest = false
        end
    )
    return newWin
end
