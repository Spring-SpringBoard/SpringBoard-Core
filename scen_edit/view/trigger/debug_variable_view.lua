DebugVariableView = VariableManagerListener:extends{}

function DebugVariableView:init(parent)
    self.parent = parent
    self:Populate()
    SB.model.variableManager:addListener(self)
end

function DebugVariableView:Populate()
    self.parent:ClearChildren()
    local variables = SB.model.variableManager:getAllVariables()
    for id, variable in pairs(variables) do
        local variablePanel = MakeComponentPanel(self.parent)
        local maxChars = 15
        local lblVariableName = Label:New {
            caption = variable.name:sub(1, maxChars),
            width = 100,
            x = 1,
            parent = variablePanel,
            align = 'left',
        }
        local lblVariableValue = Label:New {
            caption = SB.humanExpression(variable.value, "value", variable.type),
            x = 120,
            right = 5,
            parent = variablePanel,
        }
    end
end

function DebugVariableView:Dispose()
    SB.model.variableManager:removeListener(self)
end

function DebugVariableView:onVariableAdded(variableID)
    self:Populate()
end

function DebugVariableView:onVariableRemoved(variableID)
    self:Populate()
end

function DebugVariableView:onVariableUpdated(variableID)
    self:Populate()
end
