local Chili = WG.Chili
local screen0 = Chili.Screen0
local C_HEIGHT = 16
local B_HEIGHT = 24

DebugVariableView = VariableManagerListener:extends{}

function DebugVariableView:init(parent)
    self.parent = parent
    self:Populate()
    SCEN_EDIT.model.variableManager:addListener(self)
end

function DebugVariableView:Populate()
    self.parent:ClearChildren()
    local variables = SCEN_EDIT.model.variableManager:getAllVariables()
    for id, variable in pairs(variables) do
        local variablePanel = MakeComponentPanel(self.parent)
        local maxChars = 15
        local lblVariableName = Chili.Label:New {
            caption = variable.name:sub(1, maxChars),
            width = 100,
            x = 1,
            parent = variablePanel,
            align = 'left',
        }
        local lblVariableValue = Chili.Label:New {
            caption = SCEN_EDIT.humanExpression(variable.value, "value", variable.type),
            x = 120,
            right = 5,
            parent = variablePanel,
        }
    end
end

function DebugVariableView:Dispose()
    SCEN_EDIT.model.variableManager:removeListener(self)
end

function DebugVariableView:onVariableAdded(variableId)
    self:Populate()
end

function DebugVariableView:onVariableRemoved(variableId)
    self:Populate()
end

function DebugVariableView:onVariableUpdated(variableId)
    self:Populate()
end
