Field = LCS.class{}
function Field:init(field)
    self.height = 30
    for k, v in pairs(field) do
        self[k] = v
    end
end

function Field:_CompareValues(v1, v2)
    local v1Type, v2Type = type(v1), type(v2)
    if v1Type ~= v2Type then
        return false
    elseif v1Type ~= "table" then
        return v1 == v2
    else
        local kCount1 = 0
        for k, v in pairs(v1) do
            kCount1 = kCount1 + 1
            if not self:_CompareValues(v, v2[k]) then
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
end
-- Override
function Field:Validate(value)
    if value ~= nil and not self:_CompareValues(value, self.value) then
        return true, value
    end
    return false
end
function Field:Set(value, source)
    if self.inUpdate then
        return
    end
    self.inUpdate = true
    local valid, value = self:Validate(value)
    if valid then
        self.value = value
        -- invoke editor view's update
        self.ev:Update(self.name, source)
    end
    self.inUpdate = false
end
function Field:Added()
end
-- HACK: see above
function Field:_HackSetInvisibleFields(fields)
end
