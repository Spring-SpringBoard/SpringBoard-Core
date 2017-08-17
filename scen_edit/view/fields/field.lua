Field = LCS.class{}
function Field:init(field)
    self:__SetDefault("allowNil", true)
    self:__SetDefault("height", 30)
    for k, v in pairs(field) do
        self[k] = v
    end
end

function Field:__SetDefault(key, value)
    if self[key] == nil then
        self[key] = value
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
    if value == nil then
        return self.allowNil, value
    else
        return true, value
    end
end

function Field:Set(value, source)
    if self.__inUpdate then
        return
    end
    self.__inUpdate = true
    local valid, value = self:Validate(value)
    if valid and
        (self.__dontCheckIfSimilar or not self:_CompareValues(value, self.value)) then
        self.value = value
        -- invoke editor view's update
        if self.ev then
            self.ev:Update(self.name, source)
        end
    end
    self.__inUpdate = false
end

function Field:Added()
end

-- Override
function Field:Serialize()
    return self.value
end

function Field:Load(data)
    self:Set(data)
end

-- Override
function Field:Update(source)
end

-- HACK: see above
function Field:_HackSetInvisibleFields(fields)
end
