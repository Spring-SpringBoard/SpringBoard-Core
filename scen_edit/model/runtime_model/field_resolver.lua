FieldResolver = LCS.class{}

function FieldResolver:init()
end

function FieldResolver:CallExpression(expr, exprType, params, canExecuteUnsynced)
    local resolvedInputs = {}
    local fail = false
    for _, input in pairs(exprType.input) do
        local resolvedInput = self:Resolve(expr[input.name], input.type, input.rawVariable, params)
        if not input.allowNil then
            fail = fail or SCEN_EDIT.resolveAssert(resolvedInput, input, expr)
        end
        resolvedInputs[input.name] = resolvedInput
    end
    if fail then
        return
    end

    if exprType.execute == nil and (exprType.executeUnsynced and canExecuteUnsynced) then
        SCEN_EDIT.rtModel:ExecuteUnsynced(exprType.name, resolvedInputs)
        return
    end
    if not exprType.execute then
        Log.Error("There is no function \"execute\" for expression: " .. exprType.name)
    else
        local result = exprType.execute(resolvedInputs)
        if exprType.doRepeat and result then
            table.insert(SCEN_EDIT.rtModel.repeatCalls, {exprType = exprType, resolvedInputs = resolvedInputs})
        end
        return result
    end
end

function FieldResolver:Resolve(field, type, rawVariable, params)
    if field.type == "expr" then
        local typeName = field.expr[1].typeName
        local exprType = SCEN_EDIT.metaModel.functionTypes[typeName]
        return self:CallExpression(field.expr[1], exprType, params)
    elseif field.type == "var" then
        local variable = SCEN_EDIT.model.variableManager:getVariable(field.id)
        if not rawVariable then
            return self:Resolve(variable.value, variable.type, nil, params)
        else
            return variable
        end
    end
    if type == "unit" then
        local unitId = nil
        if field.type == "pred" then
            unitId = tonumber(field.id)
        elseif field.type == "spec" then
            unitId = tonumber(params.triggerUnitId)
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
            local triggerUnitId = tonumber(params.triggerUnitId)
            if triggerUnitId then
                return Spring.GetUnitDefID(triggerUnitId)
            end
        end
    elseif type == "feature" then
        local featureId = nil
        if field.type == "pred" then
            featureId = tonumber(field.id)
        elseif field.type == "spec" then
            featureId = tonumber(params.triggerFeatureId)
        end
        if featureId ~= nil then
            local springId = SCEN_EDIT.model.featureManager:getSpringfeatureId(featureId)
            if Spring.ValidFeatureID(springId) then
                return springId
            end
        end
    elseif type == "featureType" then
        if field.type == "pred" then
            return tonumber(field.id)
        elseif field.type == "spec" then
            local triggerFeatureId = tonumber(params.triggerFeatureId)
            if triggerFeatureId then
                return Spring.GetFeatureDefID(triggerFeatureId)
            end
        end
    elseif type == "team" then
        if field.type == "pred" then
            return SCEN_EDIT.model.teamManager:getTeam(field.id).id
        end
    elseif type == "area" then
        if field.type == "pred" then
            local areaId = tonumber(field.id)
            return SCEN_EDIT.model.areaManager:getArea(areaId)
        elseif field.type == "spec" then
            local areaId = tonumber(params.triggerAreaId)
            if areaId then
                return SCEN_EDIT.model.areaManager:getArea(areaId)
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
            local resolvedInput = self:Resolve(field[input.name], input.type, nil, params)
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
    elseif type == "bool" then
        if field.type == "pred" then
            return field.id
        end
    elseif type == "position" then
        if field.type == "pred" then
            return field.id
        end
    elseif type == "numericComparison" then
        return SCEN_EDIT.metaModel.numericComparisonTypes[field.cmpTypeId]
    elseif type == "identityComparison" then
        return SCEN_EDIT.metaModel.identityComparisonTypes[field.cmpTypeId]
    elseif type:find("_array") then
        local atomicType = type:sub(1, type:find("_array") - 1)
        if field.type == "pred" then
            local values = {}
            for _, element in pairs(field.id) do
                local value = self:Resolve(element, atomicType, nil, params)
                table.insert(values, value)
            end
            return values
        end
    end
end
