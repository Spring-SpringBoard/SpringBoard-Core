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
