FieldResolver = LCS.class{}

function FieldResolver:init(params)
    self.params = params
end

function FieldResolver:CallExpression(expr, exprType)
    local resolvedInputs = {}
    local fail = false
    for i = 1, #exprType.input do
        local input = exprType.input[i]    
        local resolvedInput = self:Resolve(expr[input.name], input.type, input.rawVariable)
        if not input.allowNil then
            fail = fail or SCEN_EDIT.resolveAssert(resolvedInput, input, expr)
        end
        resolvedInputs[input.name] = resolvedInput
    end
    if not fail then
        if not exprType.execute then
            SCEN_EDIT.Error("There is no function \"execute\" for expression: " .. exprType.name)
        else
            local result = exprType.execute(resolvedInputs)
            if exprType.doRepeat and result then
                table.insert(SCEN_EDIT.rtModel.repeatCalls, {exprType = exprType, resolvedInputs = resolvedInputs})
            end
            return result
        end
    end
end

function FieldResolver:Resolve(field, type, rawVariable)
    if field.type == "expr" then
        local conditionTypeName = field.expr[1].conditionTypeName
        local conditionType = SCEN_EDIT.metaModel.functionTypes[conditionTypeName]
        return self:CallExpression(field.expr[1], conditionType)
    elseif field.type == "var" then
        local variable = SCEN_EDIT.model.variableManager:getVariable(field.id)
        if not rawVariable then
            return self:Resolve(variable.value, variable.type)
        else
            return variable
        end
    end
    if type == "unit" then
        local unitId = nil
        if field.type == "pred" then
            unitId = tonumber(field.id)
        elseif field.type == "spec" then
            if field.name == "Trigger unit" then
                unitId = tonumber(self.params.triggerUnitId)
            end
        elseif field.type == "var" then
        end
        if unitId ~= nil then
            local springId = SCEN_EDIT.model.unitManager:getSpringUnitId(unitId)
            if Spring.ValidUnitID(springId) then
                return springId
            end
        end
    elseif type == "unitType" then        
        if field.type == "pred" then
            return tonumber(field.id)
        elseif field.type == "spec" then
            if field.name == "Trigger unit type" then
                local triggerUnitId = tonumber(self.params.triggerUnitId)
                if triggerUnitId then
                    return Spring.GetUnitDefID(triggerUnitId)                        
                end
            end
        end
    elseif type == "team" then
        if field.type == "pred" then
            return SCEN_EDIT.model.teams[field.id].id
        end
    elseif type == "area" then
        if field.type == "pred" then
            local areaId = tonumber(field.id)
            return SCEN_EDIT.model.areaManager:getArea(areaId)
        elseif field.type == "spec" then
            if field.name == "Trigger area" then
                local areaId = tonumber(self.params.triggerAreaId)
                if areaId then
                    return SCEN_EDIT.model.areaManager:getArea(areaId)
                end
            end
        end
    elseif type == "trigger" then
        if field.type == "pred" then
            local triggerId = tonumber(field.id)
            return SCEN_EDIT.model.triggerManager:getTrigger(triggerId)
        end
    elseif type == "order" then
        local orderType = SCEN_EDIT.metaModel.orderTypes[field.orderTypeName]
        local order = {
            orderTypeName = field.orderTypeName,
            input = {}
        }
        for i = 1, #orderType.input do
            local input = orderType.input[i]    
            local resolvedInput = self:Resolve(field[input.name], input.type)
            order.input[input.name] = resolvedInput
        end
        return order
    elseif type == "string" then
        if field.type == "pred" then
            return field.id
        end
    elseif type == "number" then
        if field.type == "pred" then
            return field.id
        end
    elseif type == "numericComparison" then
        return SCEN_EDIT.metaModel.numericComparisonTypes[field.cmpTypeId]
    elseif type == "identityComparison" then
        return SCEN_EDIT.metaModel.identityComparisonTypes[field.cmpTypeId]
    elseif type:find("_array") then
        local atomicType = type:sub(type:find("_array"))
    end
end
