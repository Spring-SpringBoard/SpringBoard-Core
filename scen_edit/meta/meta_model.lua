MetaModel = LCS.class{}
SCEN_EDIT_META_MODEL_DIR = SCEN_EDIT_DIR .. "meta/"

function MetaModel:init()
    SCEN_EDIT.IncludeDir(SCEN_EDIT_META_MODEL_DIR)

    self.numericComparisonTypes = {"==", "~=", "<=", ">=", ">", "<"} -- maybe use more user friendly signs
    self.identityComparisonTypes = {"is", "is not"} -- maybe use more user friendly signs

    self:LoadVariableTypes()
    --TODO: add array type
    --local arrayTypes = {}
end

function MetaModel:LoadEventTypes(eventTypes)
    self.eventTypes = eventTypes
    self.eventTypes = SCEN_EDIT.CreateNameMapping(self.eventTypes)
end

function MetaModel:LoadFunctionTypes(functionTypes)
    for i = 1, #functionTypes do
        local functionType = functionTypes[i]
        functionType.input = SCEN_EDIT.parseData(functionType.input)
    end
    self.functionTypes = SCEN_EDIT.CreateNameMapping(functionTypes)
    self.functionTypesByInput = SCEN_EDIT.GroupByField(functionTypes, "input")
    self.functionTypesByOutput = SCEN_EDIT.GroupByField(functionTypes, "output")
    
    local coreTypes = SCEN_EDIT.coreTypes()
    -- fill missing
    for k, v in pairs(self.functionTypesByInput) do
        self.functionTypesByInput[k] = SCEN_EDIT.CreateNameMapping(v)
    end
    for k, v in pairs(self.functionTypesByOutput) do
        self.functionTypesByOutput[k] = SCEN_EDIT.CreateNameMapping(v)
    end
    --[[
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

function MetaModel:LoadActionTypes(actionTypes)
    for i = 1, #actionTypes do
        local actionType = actionTypes[i]
        actionType.input = SCEN_EDIT.parseData(actionType.input)
    end
    self.actionTypes = SCEN_EDIT.CreateNameMapping(actionTypes)
end

function MetaModel:LoadVariableTypes()
    --add variables for core types
    self.variableTypes = {"unit", "unitType", "team", "player", "area", "string", "number", "bool"}    
    for i = 1, #self.variableTypes do
        local variableType = self.variableTypes[i]
        local arrayType = variableType .. "_array"
        table.insert(self.variableTypes, arrayType)
    end
end

--TODO: abstract order types out of the meta model
function MetaModel:LoadOrderTypes(orderTypes)
    for i = 1, #orderTypes do
        local orderType = orderTypes[i]
        orderType.input = SCEN_EDIT.parseData(orderType.input)
    end
    self.orderTypes = SCEN_EDIT.CreateNameMapping(orderTypes)
end
