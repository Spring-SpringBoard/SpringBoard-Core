MetaModel = LCS.class{}
SCEN_EDIT_META_MODEL_DIR = SCEN_EDIT_DIR .. "meta/"

function MetaModel:init()
    SCEN_EDIT.IncludeDir(SCEN_EDIT_META_MODEL_DIR)

    self.numericComparisonTypes = {"==", "~=", "<=", ">=", ">", "<"} -- maybe use more user friendly signs
    self.identityComparisonTypes = {"is", "is not"} -- maybe use more user friendly signs

    self:SetVariableTypes()
    --TODO: add array type
    --local arrayTypes = {}
end

function MetaModel:SetEventTypes(eventTypes)
    self.eventTypes = eventTypes
    self.eventTypes = SCEN_EDIT.CreateNameMapping(self.eventTypes)
    for _, eventType in pairs(eventTypes) do
        if eventType.param ~= nil then
            eventType.param = SCEN_EDIT.parseData(eventType.param)
        else
            eventType.param = {}
        end
    end
end

function MetaModel:SetFunctionTypes(functionTypes)
    for _, functionType in pairs(functionTypes) do
        if functionType.input ~= nil then
            functionType.input = SCEN_EDIT.parseData(functionType.input)
        else
            functionType.input = {}
        end
    end
    self.functionTypes = SCEN_EDIT.CreateNameMapping(functionTypes)
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
    self.functionTypesByOutput = SCEN_EDIT.GroupByField(functionTypes, "output")

    -- fill missing
    for k, v in pairs(self.functionTypesByInput) do
        self.functionTypesByInput[k] = SCEN_EDIT.CreateNameMapping(v)
    end
    for k, v in pairs(self.functionTypesByOutput) do
        self.functionTypesByOutput[k] = SCEN_EDIT.CreateNameMapping(v)
    end
    --[[
    local coreTypes = SCEN_EDIT.coreTypes()
    for i = 1, #coreTypes do
        local coreType = coreTypes[i]
        if self.functionTypesByInput[coreType.name] then
            self.functionTypesByInput[coreType.name] = SCEN_EDIT.CreateNameMapping(self.functionTypesByInput[coreType.name])
        end
        if self.functionTypesByOutput[coreType.name] then
            self.functionTypesByOutput[coreType.name] = SCEN_EDIT.CreateNameMapping(self.functionTypesByOutput[coreType.name])
        end
    end
    --]]
end

function MetaModel:SetActionTypes(actionTypes)
    for _, actionType in pairs(actionTypes) do
        if actionType.input ~= nil then
            actionType.input = SCEN_EDIT.parseData(actionType.input)
        else
            actionType.input = {}
        end
    end
    self.actionTypes = SCEN_EDIT.CreateNameMapping(actionTypes)
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
        orderType.input = SCEN_EDIT.parseData(orderType.input)
    end
    self.orderTypes = SCEN_EDIT.CreateNameMapping(orderTypes)
end
