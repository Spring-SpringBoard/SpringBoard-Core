SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

VariablesWindow = EditorView:extends{}

function VariablesWindow:init()
    self:super("init")

    self.btnAddVariable = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Add variable",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "variable-add.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                self:AddVariable()
                self.btnAddVariable:SetPressedState(true)
            end
        },
    })

    self.variablesPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        width = "100%",
        autosize = true,
        resizeItems = false,
    }
    local children = {
        ScrollPanel:New {
            x = 0,
            y = 80,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = {
                self.variablesPanel
            },
        },
        self.btnAddVariable,
    }

    self:Populate()
    local variableManagerListener = VariableManagerListenerWidget(self)
    SB.model.variableManager:addListener(variableManagerListener)

    self:Finalize(children)
end

function VariablesWindow:AddVariable()
    local variable = {
        type = "number",
        value = {},
        name = "New variable",
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

function VariablesWindow:MakeRemoveVariableWindow(variableId)
    local cmd = RemoveVariableCommand(variableId)
    SB.commandManager:execute(cmd)
end

function VariablesWindow:Populate()
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
            right = 0,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = variableStackPanel,
            padding = {2, 2, 2, 2},
            tooltip = "Remove variable",
            classname = "negative_button",
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "cancel.png",
                    height = "100%",
                    width = "100%",
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

function VariablesWindow:MakeVariableWindow(variable, edit)
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
            self.btnAddVariable:SetPressedState(false)
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