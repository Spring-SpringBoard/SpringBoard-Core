return {
    actions = function()
        local variableAssignments = {}
        allTypes = SCEN_EDIT.coreTypes()
        for i = 1, #allTypes do
            local type = allTypes[i]

            local variableAssignment = {
                humanName = "Assign " .. type.humanName .. " variable",
                name = type.name .. "_VARIABLE_ASSIGN",
                input = { 
                    {
                        name = "variable",
                        rawVariable = "true",
                        type = type.name,
                    },
                    {
                        name = type.name,
                        type = type.name,
                    },
                },
                --        output = type.name,
                execute = function(input)
                    local unitModelId = SCEN_EDIT.model.unitManager:getModelUnitId(input.unit)
                    local newValue = SCEN_EDIT.deepcopy(input.variable)
                    newValue.value.id = unitModelId
                    SCEN_EDIT.model.variableManager:setVariable(variable.id, newValue)

                    --local array = input[arrayType]
                    --local index = input.number
                    --return array[index]
                end,
            }

            table.insert(variableAssignments, variableAssignment)
        end

        return {
            {
                humanName = "Spawn unit", 
                name = "SPAWN_UNIT",
                input = { "unitType", "team", "area" },
                execute = function (input)
                    local unitType = input.unitType
                    local area = input.area
                    local team = input.team
                    local x = (area[1] + area[3]) / 2                
                    local z = (area[2] + area[4]) / 2
                    local y = Spring.GetGroundHeight(x, z)                                                
                    Spring.CreateUnit(unitType, x, y, z, 0, team)

                    local color = SCEN_EDIT.model.teams[team].color
                    SCEN_EDIT.displayUtil:displayText("Spawned", {x, y, z}, color )
                end
            },
            {
                humanName = "Issue order", 
                name = "ISSUE_ORDER",
                input = { "unit", "order" },
                execute = function (input)
                    local orderTypeName = input.order.orderTypeName
                    local newInput = {
                        unit = input.unit,
                        params = input.order.input,
                    }

                    Spring.GiveOrderToUnit(input.unit, CMD.STOP, {}, {})
                    SCEN_EDIT.metaModel.orderTypes[orderTypeName].execute(newInput)
                    local x, y, z = Spring.GetUnitPosition(input.unit)
                    local color = SCEN_EDIT.model.teams[Spring.GetUnitTeam(input.unit)].color
                    SCEN_EDIT.displayUtil:displayText("Issued order", {x, y, z}, color )
                end
            },
            {
                humanName = "Add order", 
                name = "ADD_ORDER",
                input = { "unit", "order" },
                execute = function (input)
                    local orderTypeName = input.order.orderTypeName
                    local newInput = {
                        unit = input.unit,
                        params = input.order.input,
                    }

                    SCEN_EDIT.metaModel.orderTypes[orderTypeName].execute(newInput)
                    local x, y, z = Spring.GetUnitPosition(input.unit)
                    local color = SCEN_EDIT.model.teams[Spring.GetUnitTeam(input.unit)].color
                    SCEN_EDIT.displayUtil:displayText("Added order", {x, y, z}, color )
                end
            },
            {
                humanName = "Issue order to units", 
                name = "ISSUE_ORDER_TO_UNITS",
                input = { "unit_array", "order" },
                execute = function (input)
                    for i = 1, #input.unit_array do
                        local unit = input.unit_array[i]
                        local orderTypeName = input.order.orderTypeName
                        local newInput = {
                            unit = unit,
                            params = input.order.input,
                        }
                        SCEN_EDIT.metaModel.orderTypes[orderTypeName].execute(newInput)
                    end
                end
            },
            {
                humanName = "Unit say", 
                name = "UNIT_SAY",
                input = { "unit", "string" },
                execute = function (input)
                    local unit = input.unit
                    local text = input.string

                    SCEN_EDIT.displayUtil:unitSay(unit, text)
                end
            },
            {
                humanName = "Remove unit", 
                name = "REMOVE_UNIT",
                input = { "unit" },
                execute = function (input)
                    local unit = input.unit                
                    local x, y, z = Spring.GetUnitPosition(unit)

                    local color = SCEN_EDIT.model.teams[Spring.GetUnitTeam(unit)].color
                    Spring.DestroyUnit(unit, false, true)
                    SCEN_EDIT.displayUtil:displayText("Removed", {x, y, z}, color)
                end
            },
            {
                humanName = "Move unit", 
                name = "MOVE_UNIT",
                input = { "unit", "area" },
                execute = function (input)
                    local unit = input.unit
                    local area = input.area
                    local x = (area[1] + area[3]) / 2
                    local z = (area[2] + area[4]) / 2
                    local y = Spring.GetGroundHeight(x, z)
                    Spring.SetUnitPosition(unit, x, y, z)
                    Spring.GiveOrderToUnit(unit, CMD.STOP, {}, {})
                end
            },
            {
                humanName = "Transfer unit", 
                name = "TRANSFER_UNIT",
                input = { "unit", "team" },
                execute = function (input)
                    local unit = input.unit
                    local team = input.team
                    Spring.TransferUnit(unit, team, false)
                end
            },
            {
                humanName = "Enable trigger", 
                name = "ENABLE_TRIGGER",
                input = { "trigger" },
                execute = function (input)
                    local trigger = input.trigger
                    SCEN_EDIT.model.triggerManager:enableTrigger(trigger.id)
                end
            },
            {
                humanName = "Disable trigger",
                name = "DISABLE_TRIGGER",
                input = { "trigger" },
                execute = function (input)
                    local trigger = input.trigger
                    SCEN_EDIT.model.triggerManager:disableTrigger(trigger.id)
                end
            },
            {
                humanName = "Hello world",
                name = "HELLO_WORLD",
                input = {},
                execute = function (input)
                    Spring.Echo("Hello world")
                end
            },
            {
                humanName = "Execute trigger after n seconds",
                name = "EXECUTE_TRIGGER_AFTER_TIME",
                input = { "trigger", "number" },
                doRepeat = true,
                execute = function (input)
                    local trigger = input.trigger
                    if not input.converted then
                        input.converted = true
                        input.number = input.number * 30
                    end
                    if input.number > 0 then
                        input.number = input.number - 1
                        return true
                    else
                        SCEN_EDIT.rtModel:ExecuteTrigger(trigger.id)
                    end
                end
            },
            {
                humanName = "Camera follow unit",
                name = "CAMERA_FOLLOW_UNIT",
                input = { "unit" },
                execute = function (input)
                    SCEN_EDIT.displayUtil:followUnit(input.unit)
                end
            },
            {
                humanName = "Play sound",
                name = "PLAY_SOUND_FILE",
                input = { "string" },
                execute = function (input)
                    SCEN_EDIT.displayUtil:playSound(input.string)
                end
            },
            {
                humanName = "Test result",
                name = "TEST_RESULT",
                input = { 
                    {
                        type = "number",
                        name = "name",
                        humanName = "Test number:",
                    },
                    {
                        type = "bool",
                        name = "result",
                        humanName = "Success:",
                    },
                },
                execute = function (input)
                end
            },
            unpack(variableAssignments),
            --[[
            --TODO.. variables, yeah..
            {
            humanName = "Assign variable",
            name = "VARIABLE_ASSIGN",
            input = { 
            {
            name = "variable",
            rawVariable = "true",
            type = "unit",
            },
            {
            name = "unit",
            type = "unit"
            },
            },
            execute = function(input)
            local unitModelId = SCEN_EDIT.model.unitManager:getModelUnitId(input.unit)
            local newValue = SCEN_EDIT.deepcopy(input.variable)
            newValue.value.id = unitModelId
            SCEN_EDIT.model.variableManager:setVariable(variable.id, newValue)
            end,
            },--]]
        }
    end,

    functions = function()
        local functions = {}
        local coreTypes = SCEN_EDIT.coreTypes()
        local complexTypes = SCEN_EDIT.complexTypes()
        local allTypes = coreTypes
        for i = 1, #complexTypes do
            local complexType = complexTypes[i]
            table.insert(allTypes, complexType)
        end

        for i = 1, #allTypes do
            local basicType = allTypes[i]        
            if basicType.canCompare == nil or basicType.canCompare == true then
                local relType
                if basicType.name == "number" then
                    relType = "numericComparison"
                else
                    relType = "identityComparison"
                end
                local compareCond = {
                    humanName = "Compare " .. basicType.name,
                    name = "compare_" .. basicType.name,
                    input = {
                        {
                            name = "first",
                            type = basicType.name,
                            allowNil = true,
                        },
                        {
                            name = "relation",
                            type = relType,
                        },
                        {
                            name = "second",
                            type = basicType.name,
                            allowNil = true,
                        },
                    },
                    execute = function(input) 
                        local first = input.first
                        local second = input.second
                        local relation = input.relation
                        if relation == "is" or relation == "is not" then
                            local isSame = false
                            -- note: we want nil to be ~= to nil
                            if first ~= nil and second ~= nil then
                                if basicType.name ~= "area" then
                                    isSame = first == second
                                else
                                    isSame = first[1] == second[1] and first[2] == second[2] and
                                    first[3] == second[3] and first[4] == second[4]
                                end
                            end
                            return isSame == (relation == "is")
                        end
                    end,
                    output = "bool",
                }
                table.insert(functions, compareCond)
            end
        end
        local coreTransforms = {
            {
                humanName = "Unit type",
                name = "UNIT_TYPE",
                input = { "unit" },
                output = "unitType",
                execute = function(input)
                    return Spring.GetUnitDefID(input.unit)
                end,
            },
            {
                humanName = "Unit team",
                name = "UNIT_TEAM",
                input = { "unit" },
                output = "team",            
                execute = function(input)
                    return Spring.GetUnitTeam(input.unit)
                end,
            },
            {
                humanName = "Unit alive",
                name = "UNIT_ALIVE",
                input = { 
                    {
                        name = "unit",
                        type = "unit",
                        allowNil = true,
                    },
                },
                output = "bool",
                execute = function(input)
                    return not (not input.unit or Spring.GetUnitIsDead(input.unit))
                end,
            },
            {
                humanName = "Unit HP",
                name = "UNIT_HP",
                input = { "unit" },
                output = "number",            
                execute = function(input)
                    return Spring.GetUnitHealth(input.unit)
                end,
            },
            {
                humanName = "Unit HP%",
                name = "UNIT_HP_PERCENT",
                input = { "unit" },
                output = "number",            
                execute = function(input)
                    local hp, maxHp Spring.GetUnitHealth(input.unit)
                    return hp / maxHp
                end,
            },
            {
                humanName = "Units in Area",
                name = "UNITS_IN_AREA",
                input = { "area" },
                output = "unit_array",
                execute = function(input)
                    return Spring.GetUnitsInRectangle(unpack(input.area))
                end,
            },
            {
                humanName = "Unit is in Area",
                name = "UNIT_IS_IN_AREA",
                input = { "area", "unit" },
                output = "bool",
                execute = function(input)
                    local units = Spring.GetUnitsInRectangle(unpack(input.area))
                    for _, id in pairs(units) do
                        if id == input.unit then
                            return true
                        end
                    end
                    return false
                end,
            },
            {
                humanName = "Trigger disabled",
                name = "TRIGGER_DISABLED",
                input = { "trigger" },
                output = "bool",
                execute = function(input)
                    return not input.trigger.enabled
                end,
            },
            {
                humanName = "Trigger enabled",
                name = "TRIGGER_ENABLED",
                input = { "trigger" },
                output = "bool",
                execute = function(input)
                    return input.trigger.enabled
                end,
            },
            {
                humanName = "Not",
                name = "NOT_CONDITION",
                input = { "bool" },
                output = "bool",
                execute = function(input)
                    return not input.bool
                end,
            },
            {
                humanName = "Or",
                name = "OR_CONDITIONS",
                input = { "bool_array" },
                output = "bool",
                execute = function(input)
                    return true
                end,
            },
            {
                humanName = "And",
                name = "AND_CONDITIONS",
                input = { "bool_array" },
                output = "bool",
                execute = function(input)
                    return false
                end,
            },        
        }
        for i = 1, #coreTransforms do
            local coreTransform = coreTransforms[i]
            table.insert(functions, coreTransform)
        end

        local arrayTypes = {}
        for i = 1, #allTypes do
            local type = allTypes[i]
            local arrayType = type.name .. "_array"

            local itemFromArray = {
                humanName = type.humanName .. " in array at position",
                name = arrayType .. "_INDEXING",
                input = { arrayType, "number" },
                output = type.name,
                execute = function(input)
                    local array = input[arrayType]
                    local index = input.number
                    return array[index]
                end,
            }
            table.insert(functions, itemFromArray)
        end
        return functions
    end,
    orders = function()
        return {
            {
                humanName = "Move to area",
                name = "MOVE_AREA",
                input = { "area" },
                execute = function(input)
                    local unit = input.unit
                    local area = input.params.area
                    local x = (area[1] + area[3]) / 2
                    local z = (area[2] + area[4]) / 2
                    local y = Spring.GetGroundHeight(x, z)

                    Spring.GiveOrderToUnit(unit, CMD.MOVE, { x, y, z }, {"shift"})
                end,
            },
            {
                humanName = "Attack unit",
                name = "ATTACK_UNIT",
                input = {                
                    {
                        name = "target",
                        type = "unit",
                        humanName = "Target unit",
                    },
                },
                execute = function(input)
                    local unit = input.unit
                    local target = input.params.target

                    Spring.GiveOrderToUnit(unit, CMD.ATTACK, { target }, {"shift"})
                end,
            },
            {
                humanName = "Cancel current order",
                name = "CANCEL_ORDER",
                input = {},
                execute = function(input)
                    local unit = input.unit

                    Spring.GiveOrderToUnit(unit, CMD.STOP, {}, {"shift"})
                end,
            },
            {
                humanName = "Wait with current order",
                name = "WAIT_ORDER",
                input = {},
                execute = function(input)
                    local unit = input.unit

                    Spring.GiveOrderToUnit(unit, CMD.WAIT, {}, {"shift"})
                end,
            },
            {
                humanName = "Patrol to area",
                name = "PATROL_AREA",
                input = { "area" },
                execute = function(input)
                    local unit = input.unit
                    local area = input.params.area
                    local x = (area[1] + area[3]) / 2
                    local z = (area[2] + area[4]) / 2
                    local y = Spring.GetGroundHeight(x, z)

                    Spring.Echo("Patrol " .. tostring(unit) .. " ", x, y, z)
                    Spring.GiveOrderToUnit(unit, CMD.PATROL, { x, y, z }, {"shift"})
                end,
            },
            {
                humanName = "Fight to area",
                name = "FIGHT_AREA",
                input = { "area" },
                execute = function(input)
                    local unit = input.unit
                    local area = input.params.area
                    local x = (area[1] + area[3]) / 2
                    local z = (area[2] + area[4]) / 2
                    local y = Spring.GetGroundHeight(x, z)

                    Spring.GiveOrderToUnit(unit, CMD.FIGHT, { x, y, z }, {"shift"})
                end,
            },
            {
                humanName = "Guard unit",
                name = "GUARD_UNIT",
                input = {                
                    {
                        name = "target",
                        type = "unit",
                        humanName = "Target unit",
                    },
                },
                execute = function(input)
                    local unit = input.unit
                    local target = input.params.target

                    Spring.GiveOrderToUnit(unit, CMD.GUARD, { target }, {"shift"})
                end,
            },
            {
                humanName = "Repair unit",
                name = "REPAIR_UNIT",
                input = {                
                    {
                        name = "target",
                        type = "unit",
                        humanName = "Target unit",
                    },
                },
                execute = function(input)
                    local unit = input.unit
                    local target = input.params.target

                    Spring.GiveOrderToUnit(unit, CMD.REPAIR, { target }, {"shift"})
                end,
            },
            {
                humanName = "Repair area",
                name = "REPAIR_AREA",
                input = { type = "area" },
                execute = function(input)
                    local unit = input.unit
                    local area = input.params.area
                    local x = (area[1] + area[3]) / 2
                    local z = (area[2] + area[4]) / 2
                    local y = Spring.GetGroundHeight(x, z)

                    Spring.GiveOrderToUnit(unit, CMD.REPAIR, { x, y, z }, {"shift"})
                end,
            },
        }
    end

}
