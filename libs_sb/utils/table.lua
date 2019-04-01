Table = Table or {}

-- Merge in place
-- TODO: make a non inplace variant too
function Table.Merge(originalTable, overrideTable)
    for k, v in pairs(overrideTable) do
        if type(v) == 'table' then
            local sv = type(originalTable[k])
            if sv == 'table' or sv == 'nil' then
                if sv == 'nil' then
                    originalTable[k] = {}
                end
                Table.Merge(originalTable[k], v)
            end
        elseif originalTable[k] == nil then
            originalTable[k] = v
        end
    end
    return originalTable
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

-- This function is a workaround for the # operator which fails with associative
-- arrays.
function Table.IsEmpty(t)
    -- luacheck: ignore
    for _ in pairs(t) do
        return false
    end
    return true
end

function Table.GetSize(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
    end
    return i
end

function Table.Filter(t, f)
    local ret = {}
    for k, v in pairs(t) do
        if f(v) then
            ret[k] = v
        end
    end
    return ret
end

function Table.GetKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

function Table.GetValues(tbl)
    local values = {}
    for _, v in pairs(tbl) do
        table.insert(values, v)
    end
    return values
end

function Table.GetField(origArray, field)
    local newArray = {}
    for k, v in pairs(origArray) do
        table.insert(newArray, v[field])
    end
    return newArray
end

function Table.GetIndex(table, value)
    assert(value ~= nil, "Table.GetIndex called with nil value.")
    for i = 1, #table do
        if table[i] == value then
            return i
        end
    end
end

-- basically does origTable = newTableValues but instead uses the old table reference
function Table.SetTableValues(origTable, newTable)
    for k in pairs(origTable) do
        origTable[k] = nil
    end
    for k in pairs(newTable) do
        origTable[k] = newTable[k]
    end
end

function Table.SortByAttr(t, attrName)
    assert(attrName ~= nil, "Sort attribute name is nil")

    local sortedTable = {}
    for k, v in pairs(t) do
        table.insert(sortedTable, v)
    end
    table.sort(sortedTable,
        function(a, b)
            return a[attrName] < b[attrName]
        end
    )
    return sortedTable
end

function Table.Compare(v1, v2)
    local v1Type, v2Type = type(v1), type(v2)
    if v1Type ~= v2Type then
        return false
    end
    if v1Type ~= "table" then
        return v1 == v2
    end

    local kCount1 = 0
    for k, v in pairs(v1) do
        kCount1 = kCount1 + 1
        if not Table.Compare(v, v2[k]) then
            return false
        end
    end
    local kCount2 = 0
    for k, v in pairs(v2) do
        kCount2 = kCount2 + 1
    end
    if kCount1 ~= kCount2 then
        return false
    end
    return true
end

function Table.ShallowCopy(t)
    local ret = {}
    for k, v in pairs(t) do
        ret[k] = v
    end
    return ret
end

function Table.DeepCopy(t)
    if type(t) ~= 'table' then
        return t
    end
    local mt = getmetatable(t)
    local res = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then
            v = Table.DeepCopy(v)
        end
        res[k] = v
    end
    setmetatable(res, mt)
    return res
end

function Table.Contains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

-- very simple (and probably inefficient) implementation of unique()
function Table.Unique(t)
    -- Use values as keys in a new table (to guarantee uniqueness)
    local valueKeys = {}
    for _, v in pairs(t) do
        valueKeys[v] = true
    end

    -- convert it back to a normal array-like table
    local values = {}
    for k, _ in pairs(valueKeys) do
        table.insert(values, k)
    end
    return values
end

-- FIXME
-- FIXME: Cleanup everything below
-- FIXME
function Table.CreateNameMapping(origArray)
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
