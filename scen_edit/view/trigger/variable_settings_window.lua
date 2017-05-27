SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

VariableSettingsWindow = EditorView:extends{}

function VariableSettingsWindow:init()
    self:super("init")

    local btnAddVariable = Button:New {
        caption='+ Variable',
        width='40%',
        x = 1,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        backgroundColor = SB.conf.BTN_ADD_COLOR,
        OnClick={
            function()
                self:AddVariable()
            end}
    }
    self.variablesPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    local children = {
        ScrollPanel:New {
            x = 1,
            y = 15,
            right = 5,
            bottom = SB.conf.C_HEIGHT * 2,
            children = {
                self.variablesPanel
            },
        },
        btnAddVariable,
    }

    self:Populate()
    local variableManagerListener = VariableManagerListenerWidget(self)
    SB.model.variableManager:addListener(variableManagerListener)

    self:Finalize(children)
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
        Log.Error("Error adding variable", msg)
    end
--[[    local newVariable = SB.model:NewVariable("number")
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
    SB.commandManager:execute(cmd)
end

function VariableSettingsWindow:Populate()
    self.variablesPanel:ClearChildren()
    local variables = SB.model.variableManager:getAllVariables()
    for _, variable in pairs(variables) do
        local variableStackPanel = MakeComponentPanel(self.variablesPanel)
        variableStackPanel.variableId = variable.id
        local btnEditVariable = Button:New {
            caption = variable.name,
            right = SB.conf.B_HEIGHT + 10,
            x = 1,
            height = SB.conf.B_HEIGHT,
            _toggle = nil,
            parent = variableStackPanel,
        }
        local btnRemoveVariable = Button:New {
            caption = "",
            right = 1,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = variableStackPanel,
            padding = {0, 0, 0, 0},
            children = {
                Image:New {
                    tooltip = "Remove variable",
                    file=SB_IMG_DIR .. "list-remove.png",
                    height = SB.conf.B_HEIGHT,
                    width = SB.conf.B_HEIGHT,
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
            SB.commandManager:execute(cmd)
        end
    )
    newWin:UpdatePanel(variable)

    local sw = self.window
    local nw = newWin.window
    nw.x = 500
    nw.y = 500

    SB.SetControlEnabled(sw, false)
    table.insert(nw.OnDispose,
        function()
            SB.SetControlEnabled(sw, true)
        end
    )
    return newWin
end

VariableManagerListenerWidget = VariableManagerListener:extends{}

function VariableManagerListenerWidget:init(variableWindow)
    self.variableWindow = variableWindow
end

function VariableManagerListenerWidget:onVariableAdded(variableId)
    self.variableWindow:Populate()
end

function VariableManagerListenerWidget:onVariableRemoved(variableId)
    self.variableWindow:Populate()
end

function VariableManagerListenerWidget:onVariableUpdated(variableId)
    self.variableWindow:Populate()
end
