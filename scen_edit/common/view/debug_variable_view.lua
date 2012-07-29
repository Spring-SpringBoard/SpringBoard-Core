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
    for i = 1, #variables  do		
        local variable = variables[i]
        local variablePanel = MakeComponentPanel(self.parent)
        local maxChars = 15
        local lblVariableName = Chili.Label:New {
            caption = variable.name:sub(1, maxChars),
            width = 100,
            x = 1,
            parent = variablePanel,
        }
        local btnExecuteVariable = Chili.Button:New {
            caption = "Execute",
            right = B_HEIGHT + 120,
            width = 100,
--            x = 110,
            height = B_HEIGHT,
            parent = variablePanel,
            OnClick = {
                function()
                    local cmd = ExecuteVariableCommand(variable.id)
                    SCEN_EDIT.commandManager:execute(cmd)
                end
            },
        }
        local btnExecuteVariableActions = Chili.Button:New {
            caption = "Execute actions",
            right = 1,
            width = 120,
            height = B_HEIGHT,
            parent = variablePanel,
            OnClick = {
                function() 
                    local cmd = ExecuteVariableActionsCommand(variable.id)
                    SCEN_EDIT.commandManager:execute(cmd)
                end
            },
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

