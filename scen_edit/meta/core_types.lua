function SB.coreTypes()
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
            humanName = "Feature",
            name = "feature",
        },
        {
            humanName = "Feature type",
            name = "featureType",
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
            sources = {"pred", "spec", "expr"},
        },
        {
            humanName = "Trigger",
            name = "trigger",
            sources = {"pred", "spec", "expr"},
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
            sources = {"pred"},
            canCompare = false,
        },
        {
            humanName = "Identity comparison",
            name = "identityComparison",
            sources = {"pred"},
            canCompare = false,
        },
        {
            humanName = "Function",
            name = "function",
            sources = {"pred", "spec", "expr"},
            canCompare = false,
        },
        {
            humanName = "Position",
            name = "position",
        },
    }
end

local function _definitions()
    return {
        type = {
            mandatory = true,
            type = "string",
        },
        name = {
            mandatory = false,
            type = "string",
            parseFunction = function(d)
                if d.name == nil then
                    d.name = d.type
                end
            end,
        },
        humanName = {
            mandatory = false,
            type = "string",
            parseFunction = function(d)
                if d.humanName == nil then
                    d.humanName = d.name
                end
            end,
        },
        raw = {
            mandatory = false,
            type = "boolean",
            default = false,
        },
        allowNil = {
            mandatory = false,
            type = "boolean",
            default = false,
        },
        input = {
            mandatory = false,
            parseFunction = function(d)
                if d.type ~= "function" and d.type ~= "action" then
                    Log.Error("parseFunction specified for \"input\" key in field: \"" .. tostring(d.type) .. "\"")
                    return
                end
                if d.input then
                    d.input = SB.parseData(d.input)
                end
            end,
        },
        output = {
            mandatory = false,
            parseFunction = function(d)
                -- TODO: Check if the output field is valid
                if d.type ~= "function" and d.type ~= "action" then
                    Log.Error("parseFunction specified for \"output\" key in field: \"" .. tostring(d.type) .. "\"")
                    return
                end
            end,
        },
        extraSources = {
            mandatory = false,
            parseFunction = function(d)
                if d.type ~= "function" and d.type ~= "action" then
                    Log.Error("parseFunction specified for \"extraSources\" key in field: \"" .. tostring(d.type) .. "\"")
                    return
                end
                if d.extraSources then
                    d.extraSources = SB.parseData(d.extraSources)
                end
            end,
        },
    }
end
local definitions = _definitions()

--[[
function SB.complexTypes()
    return {
        {
            humanName = "Point",
            name = "point",
            input = { "number", "number"},
        }
    }
end
--]]

local function parseDataType(d)
    local errored = false
    for key, def in pairs(definitions) do
        local dValue = d[key]
        if dValue == nil then
            if def.mandatory then
                Log.Error("Error, missing field \"" .. key .. "\" of data " .. tostring(d.type))
                errored = true
            elseif def.default then
                d[key] = def.default
            end
        else
            -- Perform a type check if def has a type specified
            if def.type and (def.type ~= type(dValue)) then
                Log.Error("Error, wrong type of field: \"" .. tostring(key) ..
                    "\", expected: \"" .. tostring(def.type) ..
                    "\", got: \"" .. tostring(type(dValue)) .. "\"")
                errored = true
            end
            -- Invoke the parseFunction if it exists
            if not errored and def.parseFunction then
                def.parseFunction(d)
            end
        end
    end
    return not errored
end

function SB.parseData(data)
    local newData = {}
    -- verify unnamed objects
    if type(data) == "string" then
        data = {data}
    end
    for _, d in pairs(data) do
        if type(d) == "string" then
            d = {
                name = d,
                type = d,
            }
        end
        if type(d) == "table" then
            local success = parseDataType(d)
            if success then
                for _, d2 in pairs(newData) do
                    if d.name == d2.name then
                        Log.Error("Error, name field is duplicate")
                        succses = false
                    end
                end
            end
            if success then
                table.insert(newData, d)
            end
        else
            Log.Warning("Unexpected data " .. tostring(d) .. " of type " .. type(d))
        end
    end

    -- verify named objects
    local finalData = {}
    local dataNames = {}
    for _, d in pairs(newData) do
        if dataNames[d.name] then
            Log.Error("Data of name " .. d.name .. " already exists ")
        else
            table.insert(finalData, d)
        end
    end
    return finalData
end

function SB.resolveAssert(resolvedInput, input, expr)
    if resolvedInput == nil then
        local stringRepresentation = table.show(expr)
        Log.Error(input.name .. " cannot be resolved for : " .. stringRepresentation)
        return true
    end
    return false
end
