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
