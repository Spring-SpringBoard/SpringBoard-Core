MetaModel = LCS.class{}
SB_META_MODEL_DIR = SB_DIR .. "meta/"

function MetaModel:init()
    SB.IncludeDir(SB_META_MODEL_DIR)

    self.numericComparisonTypes = {"==", "~=", "<=", ">=", ">", "<"} -- maybe use more user friendly signs
    self.identityComparisonTypes = {"is", "is not"} -- maybe use more user friendly signs
    --TODO: add array type
    --local arrayTypes = {}
end

function MetaModel:SetEventTypes(eventTypes)
    self.eventTypes = eventTypes
    self.eventTypes = Table.CreateNameMapping(self.eventTypes)
    for _, eventType in pairs(eventTypes) do
        if eventType.param ~= nil then
            eventType.param = SB.parseData(eventType.param)
        else
            eventType.param = {}
        end
    end
end

function MetaModel:SetFunctionTypes(functionTypes)
    for _, functionType in pairs(functionTypes) do
        if functionType.input ~= nil then
            functionType.input = SB.parseData(functionType.input)
        else
            functionType.input = {}
        end
    end
    self.functionTypes = Table.CreateNameMapping(functionTypes)
    self.functionTypesByInput = {}
    for _, functionDef in pairs(self.functionTypes) do
        for _, input in pairs(functionDef.input) do
            if self.functionTypesByInput[input.name] then
                table.insert(self.functionTypesByInput[input.name], functionDef)
            else
                self.functionTypesByInput[input.name] = {functionDef}
            end
        end
    end
    self.functionTypesByOutput = SB.GroupByField(functionTypes, "output")

    -- fill missing
    for k, v in pairs(self.functionTypesByInput) do
        self.functionTypesByInput[k] = Table.CreateNameMapping(v)
    end
    for k, v in pairs(self.functionTypesByOutput) do
        self.functionTypesByOutput[k] = Table.CreateNameMapping(v)
    end
    --[[
    local coreTypes = SB.coreTypes()
    for i = 1, #coreTypes do
        local coreType = coreTypes[i]
        if self.functionTypesByInput[coreType.name] then
            self.functionTypesByInput[coreType.name] = Table.CreateNameMapping(self.functionTypesByInput[coreType.name])
        end
        if self.functionTypesByOutput[coreType.name] then
            self.functionTypesByOutput[coreType.name] = Table.CreateNameMapping(self.functionTypesByOutput[coreType.name])
        end
    end
    --]]
end

function MetaModel:SetActionTypes(actionTypes)
    for _, actionType in pairs(actionTypes) do
        if actionType.input ~= nil then
            actionType.input = SB.parseData(actionType.input)
        else
            actionType.input = {}
        end
        if actionType.param ~= nil then
            actionType.param = SB.parseData(actionType.param)
        else
            actionType.param = {}
        end
    end
    self.actionTypes = Table.CreateNameMapping(actionTypes)
end

local function CanBeVariable(type)
    local sources = type.sources
    if sources == nil then
        return true
    end

    for _, s in pairs(sources) do
        if s == "var" then
            return true
        end
    end
    return false
end

function MetaModel:GenerateVariableTypes()
    self.variableTypes = {}
    for _, dataType in pairs(self:GetAllDataTypes()) do
        if CanBeVariable(dataType) then
            table.insert(self.variableTypes, dataType.name)
            table.insert(self.variableTypes, dataType.name .. "_array")
        end
    end
end

--TODO: abstract order types out of the meta model
function MetaModel:SetOrderTypes(orderTypes)
    for _, orderType in pairs(orderTypes) do
        orderType.input = SB.parseData(orderType.input)
    end
    self.orderTypes = Table.CreateNameMapping(orderTypes)
end

function MetaModel:SetCustomDataTypes(dataTypes)
    self.customDataTypes = dataTypes
    self.allDataTypes = SB.deepcopy(SB.coreTypes())
    for _, dataType in pairs(self.customDataTypes) do
        table.insert(self.allDataTypes, dataType)
    end
end

function MetaModel:GetDataType(name)
    for _, dataType in pairs(self.allDataTypes) do
        if dataType.name == name then
            return dataType
        end
    end
end

function MetaModel:GetCustomDataType(name)
    for _, dataType in pairs(self.customDataTypes) do
        if dataType.name == name then
            return dataType
        end
    end
end

function MetaModel:GetAllDataTypes()
    return self.allDataTypes
end
