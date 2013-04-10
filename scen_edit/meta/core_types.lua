function SCEN_EDIT.coreTypes()
    return {
        {
            humanName = "Unit",
            name = "unit",
        },
        {
            humanName = "Unit type",
            name = "unitType",
        },
        {
            humanName = "Team",
            name = "team",
        },
        {
            humanName = "Area",
            name = "area",
        },
        {
            humanName = "Order",
            name = "order",
        },
        {
            humanName = "Trigger",
            name = "trigger",
            canBeVariable = false,
            canCompare = false,
        },
        {
            humanName = "Bool",
            name = "bool",
        },
        {
            humanName = "String",
            name = "string",
        },
        {
            humanName = "Number",
            name = "number",
        },
        {
            humanName = "Numeric comparison",
            name = "numericComparison",
            canBeVariable = false,
            canCompare = false,
        },
        {
            humanName = "Identity comparison",
            name = "identityComparison",
            canBeVariable = false,
            canCompare = false,
        },
    }
end

local function definitions()
    return {
        name = {
            mandatory = true,
            type = "string",
        },
        type = {
            mandatory = true,
            type = "string",
        },
        humanName = {
            mandatory = true,
            type = "string",
        },
        raw = {
            mandatory = false,
            type = "bool",
            default = false,
        },
        allowNil = {
            mandatory = false,
            type = "bool",
            default = false,
        },
    }
end

function SCEN_EDIT.parseData(data)
    local newData = {}
    -- verify unnamed objects
    for i = 1, #data do
        local d = data[i]        
        if type(d) == "string" then
            d = {
                name = d,
                type = d,
            }
        end            
        if type(d) == "table" then
            local continue = true --lua has no continue and i don't want deep nesting
            if continue and not d.type then
                Spring.Echo("Error, missing type of data " .. d.type)
                continue = false
            end
            if continue and d.name == nil then
                d.name = d.type                
            end
            if continue then
                for j = 1, #newData do
                    local d2 = newData[j]
                    if d.name == d2.name then
                        Spring.Echo("Error, name field is duplicate")
                        continue = false
                    end
                end
            end
            if continue    then
                table.insert(newData, d)
            end            
        else
            Spring.Echo("Unexpected data " .. d .. " of type " .. type(d))
        end        
    end

    -- verify named objects
    local finalData = {}
    local dataNames = {}
    for i = 1, #newData do
        local d = newData[i]
        if dataNames[d.name] then
            Spring.Echo("Data of name " .. d.name .. " already exists ")
        else
            table.insert(finalData, d)
        end
    end
    return finalData
end

function SCEN_EDIT.complexTypes()
    return {
        {
            humanName = "Point",
            name = "point",
            input = { "number", "number"},
        }
    }
end

function SCEN_EDIT.resolveAssert(resolvedInput, input, expr)
    if resolvedInput == nil then
        local stringRepresentation = table.show(expr)
        SCEN_EDIT.Error(input.name .. " cannot be resolved for : " .. stringRepresentation)
        return true
    end
    return false
end
