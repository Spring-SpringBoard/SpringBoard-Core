Table = Table or {}

function Table:Merge(table2)
    for i,v in pairs(table2) do
      if (type(v)=='table') then
        local sv = type(self[i])
        if (sv == 'table')or(sv == 'nil') then
          if (sv == 'nil') then self[i] = {} end
          Table.Merge(self[i],v)
        end
      elseif (self[i] == nil) then
        self[i] = v
      end
    end
    return self
end
