--- Field module.

--- Field class. Inherit to implement custom field types or use directly.
-- @type Field
Field = LCS.class{}

--- Field constructor.
-- @function Field()
-- @see editor.Editor
-- @tparam table opts
-- @tparam bool opts.isValid Field valid status.
-- @tparam bool opts.allowNil Allow nil values.
-- @tparam number opts.height Field height size.
function Field:init(field)
    self:__SetDefault("isValid", true)
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

function Field:_Validate(value)
    local oldIsValid = self.isValid

    self.isValid = value ~= nil or self.allowNil
    if self.isValid then
        self.isValid, value = self:Validate(value)
    end

    if oldIsValid ~= self.isValid then
        self:UpdateValidStatus()
    end
    return self.isValid, value
end


--- Set value. Will not be set if it's invalid.
-- @param value Value to set.
-- @param source Source control the value was set from.
function Field:Set(value, source)
    if self.__inUpdate then
        return
    end
    self.__inUpdate = true

    local valid, validatedValue = self:_Validate(value)
    if valid and
        (self.__dontCheckIfSimilar or not self:_CompareValues(validatedValue, self.value)) then
        self.value = validatedValue
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

--- Validate value. Override.
-- @param value Value to validate.
-- @return valid, validatedValue
function Field:Validate(value)
    return true, value
end

-- Override
function Field:UpdateValidStatus()
end