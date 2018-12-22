String = String or {}

function String.Starts(str, s)
   return string.sub(str, 1, string.len(s)) == s
end

function String.Ends(str, s)
   return s == "" or string.sub(str, -string.len(s)) == s
end

function String.Capitalize(str)
    return str:sub(1, 1):upper() .. str:sub(2)
end

function String.Trim(str)
    return str:match "^%s*(.-)%s*$"
end

-- Split the string into multiple parts separated by the div separator
function String.Split(str, div)
    assert(div ~= '' and div ~= nil, 'Missing string separator')
    local pos, arr = 0, {}
    -- for each divider found
    for st, sp in function() return string.find(str, div, pos, true) end do
        table.insert(arr, string.sub(str, pos, st - 1)) -- Attach chars left of current divider
        pos = sp + 1 -- Jump past current divider
    end
    table.insert(arr, string.sub(str, pos)) -- Attach chars right of last divider
    return arr
end