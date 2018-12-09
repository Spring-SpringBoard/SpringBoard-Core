VariableManager = Observable:extends{}

function VariableManager:init()
    self:super('init')
    self.variableIDCount = 0
    self.variables = {}
end

function VariableManager:addVariable(variable)
    if variable.id == nil then
        variable.id = self.variableIDCount + 1
    end
    self.variableIDCount = variable.id
    self.variables[variable.id] = variable
    self:callListeners("onVariableAdded", variable.id)
    return variable.id
end

function VariableManager:removeVariable(variableID)
    if variableID == nil then
        return
    end
    if self.variables[variableID] then
        self.variables[variableID] = nil
        self:callListeners("onVariableRemoved", variableID)
        return true
    else
        return false
    end
end

function VariableManager:setVariable(variableID, value)
    self.variables[variableID] = value
    self:callListeners("onVariableUpdated", variableID)
end

function VariableManager:getVariable(variableID)
    return self.variables[variableID]
end

function VariableManager:getAllVariables()
    return self.variables
end

function VariableManager:getVariablesOfType(varType)
    local vars = {}
    for id, variable in pairs(self.variables) do
        if variable.type == varType then
            vars[id] = variable
        end
    end
    return vars
end

function VariableManager:serialize()
    local retVal = {}
    for _, variable in pairs(self.variables) do
        table.insert(retVal, {
            variable = variable,
        })
    end
    return retVal
end

function VariableManager:load(data)
    self.variableIDCount = 0
    for _, kv in pairs(data) do
        local variable = kv.variable
        self:addVariable(variable)
    end
end

function VariableManager:clear()
    for variableID, _ in pairs(self.variables) do
        self:removeVariable(variableID)
    end
    self.variableIDCount = 0
    self.variables = {}
end

------------------------------------------------
-- Listener definition
------------------------------------------------
VariableManagerListener = LCS.class.abstract{}

function VariableManagerListener:onVariableAdded(variableID)
end

function VariableManagerListener:onVariableRemoved(variableID)
end

function VariableManagerListener:onVariableUpdated(variableID)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
