VariableSettingsWindow = LCS.class{}

function VariableSettingsWindow:init()
    local btnAddVariable = Button:New {
        caption='+ Variable',
        width='40%',
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_ADD_COLOR,
        OnClick={ 
            function()                 
                self:AddVariable()
            end}
    }
    local btnClose = Button:New {
        caption='Close',
        width='40%',
        x = '50%',
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
    }
    self.variablesPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self.window = Window:New {
        width = 300,
        height = 250,
        minimumSize = {150,200},
        x = 500,
        y = 300,
        parent = screen0,
        children = {
            ScrollPanel:New {
                x = 1,
                y = 15,
                right = 5,
                bottom = SCEN_EDIT.conf.C_HEIGHT * 2,
                children = { 
                    self.variablesPanel
                },
            },
            btnAddVariable,
            btnClose,
        }
    }

    btnClose.OnClick={
        function() 
            self.window:Dispose() 
        end
    }
    self:Populate()
    local variableManagerListener = VariableManagerListenerWidget(self)
    SCEN_EDIT.model.variableManager:addListener(variableManagerListener)
end

function VariableSettingsWindow:AddVariable()
    local variable = {
        type = "number",
        value = {},
        name = "new variable",
    }
    success, msg = pcall(
        function()
            self:MakeVariableWindow(variable, false)
        end
    )
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
    local newWin = VariableWindow(variable)
    table.insert(newWin.window.OnConfirm,
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
    local sw = self.window
    local nw = newWin.window
    if sw.x + sw.width + nw.width > screen0.width then
        nw.x = sw.x - nw.width
    else
        nw.x = sw.x + sw.width
    end
    nw.y = sw.y
    sw.disableChildrenHitTest = true
    sw:Invalidate()
    table.insert(nw.OnDispose, 
        function() 
            sw.disableChildrenHitTest = false
            sw:Invalidate()
        end
    )
    return newWin
end
