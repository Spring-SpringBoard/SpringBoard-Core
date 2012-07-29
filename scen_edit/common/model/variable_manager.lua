VariableManager = Observable:extends{}

function VariableManager:init()
    self:super('init')
    self.variableIdCount = 0
    self.variables = {}
end

function VariableManager:addVariable(variable)
    if variable.id == nil then
        variable.id = self.variableIdCount + 1
    end
    self.variableIdCount = variable.id
    self.variables[variable.id] = variable
    self:callListeners("onVariableAdded", variable.id)
    return variable.id
end

function VariableManager:removeVariable(variableId)
    if variableId == nil then
        return
    end
    if self.variables[variableId] then
        self.variables[variableId] = nil
        self:callListeners("onVariableRemoved", variableId)
        return true
    else
        return false
    end
end

function VariableManager:setVariable(variableId, value)
    self.variables[variableId] = value
    self:callListeners("onVariableUpdated", variableId)
end

function VariableManager:getVariable(variableId)
    return self.variables[variableId]
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
        table.insert(retVal, 
            {
                variable = variable,
            }
        )
    end
    return retVal
end

function VariableManager:load(data)
    self:clear()
    self.variableIdCount = 0
    for _, kv in pairs(data) do
        id = kv.id
        variable = kv.variable
        self:addVariable(variable)
    end
end

function VariableManager:clear()
    for variableId, _ in pairs(self.variables) do
        self:removeVariable(variableId)
    end
    self.variableIdCount = 0
    self.variables = {}
end
