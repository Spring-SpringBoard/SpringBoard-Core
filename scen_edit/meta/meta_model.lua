MetaModel = LCS.class{}
SB_META_MODEL_DIR = SB_DIR .. "meta/"

function MetaModel:init()
    SB.IncludeDir(SB_META_MODEL_DIR)

    self.numericComparisonTypes = {"==", "~=", "<=", ">=", ">", "<"} -- maybe use more user friendly signs
    self.identityComparisonTypes = {"is", "is not"} -- maybe use more user friendly signs

    self:SetVariableTypes()
    --TODO: add array type
    --local arrayTypes = {}
end

function MetaModel:SetEventTypes(eventTypes)
    self.eventTypes = eventTypes
    self.eventTypes = SB.CreateNameMapping(self.eventTypes)
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
    self.functionTypes = SB.CreateNameMapping(functionTypes)
    self.functionTypesByInput = {}
    for _, functionDef in pairs(self.functionTypes) do
        for _, input in pairs(functionDef.input) do
            if self.functionTypesByInput[input.name] then
                table.insert(self.functionTypesByInput[input.name], v)
            else
                self.functionTypesByInput[input.name] = {functionDef}
            end
        end
    end
    self.functionTypesByOutput = SB.GroupByField(functionTypes, "output")

    -- fill missing
    for k, v in pairs(self.functionTypesByInput) do
        self.functionTypesByInput[k] = SB.CreateNameMapping(v)
    end
    for k, v in pairs(self.functionTypesByOutput) do
        self.functionTypesByOutput[k] = SB.CreateNameMapping(v)
    end
    --[[
    local coreTypes = SB.coreTypes()
    for i = 1, #coreTypes do
        local coreType = coreTypes[i]
        if self.functionTypesByInput[coreType.name] then
            self.functionTypesByInput[coreType.name] = SB.CreateNameMapping(self.functionTypesByInput[coreType.name])
        end
        if self.functionTypesByOutput[coreType.name] then
            self.functionTypesByOutput[coreType.name] = SB.CreateNameMapping(self.functionTypesByOutput[coreType.name])
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
    end
    self.actionTypes = SB.CreateNameMapping(actionTypes)
end

function MetaModel:SetVariableTypes()
    --add variables for core types
    self.variableTypes = {"unit", "unitType", "team", "area", "string", "number", "bool"}
    local arrayTypes = {}
    for _, variableType in pairs(self.variableTypes) do
        table.insert(arrayTypes, variableType .. "_array")
    end
    for _, arrayType in pairs(arrayTypes) do
        table.insert(self.variableTypes, arrayType)
    end
end

--TODO: abstract order types out of the meta model
function MetaModel:SetOrderTypes(orderTypes)
    for _, orderType in pairs(orderTypes) do
        orderType.input = SB.parseData(orderType.input)
    end
    self.orderTypes = SB.CreateNameMapping(orderTypes)
end
