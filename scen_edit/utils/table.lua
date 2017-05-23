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
