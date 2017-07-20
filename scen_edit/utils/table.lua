Table = Table or {}

function Table:Merge(table2)
    for k, v in pairs(table2) do
        if type(v) == 'table' then
            local sv = type(self[k])
            if sv == 'table' or sv == 'nil' then
                if sv == 'nil' then
                    self[k] = {}
                end
                Table.Merge(self[k], v)
            end
        elseif self[k] == nil then
            self[k] = v
        end
    end
    return self
end

-- Concatenates one or more array tables into a
-- new table and returns it
function Table.Concat(...)
    local ret = {}
    local tables = {...}
    for _, tbl in ipairs(tables) do
        for _, element in ipairs(tbl) do
            table.insert(ret, element)
        end
    end
    return ret
end

-- FIXME
-- FIXME: Cleanup everything below
-- FIXME
function SB.CreateNameMapping(origArray)
    local newArray = {}
    for i = 1, #origArray do
        local item = origArray[i]
        newArray[item.name] = item
    end
    return newArray
end

function SB.GroupByField(tbl, field)
    local newArray = {}
    for _, item in pairs(tbl) do
        local fieldValue = item[field]
        if newArray[fieldValue] then
            table.insert(newArray[fieldValue], item)
        else
            newArray[fieldValue] = { item }
        end
    end
    return newArray
end

function GetKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

function GetValues(tbl)
    local values = {}
    for _, v in pairs(tbl) do
        table.insert(values, v)
    end
    return values
end

function GetField(origArray, field)
    local newArray = {}
    for k, v in pairs(origArray) do
        table.insert(newArray, v[field])
    end
    return newArray
end

function GetIndex(table, value)
    assert(value ~= nil, "GetIndex called with nil value.")
    for i = 1, #table do
        if table[i] == value then
            return i
        end
    end
end

-- basically does origTable = newTableValues but instead uses the old table reference
function SetTableValues(origTable, newTable)
    for k in pairs(origTable) do
        origTable[k] = nil
    end
    for k in pairs(newTable) do
        origTable[k] = newTable[k]
    end
end

function SortByName(t, name)
    local sortedTable = {}
    for k, v in pairs(t) do
        table.insert(sortedTable, v)
    end
    table.sort(sortedTable,
        function(a, b)
            return a[name] < b[name]
        end
    )
    return sortedTable
end
