_ObjectBridge = LCS.class{}

function _ObjectBridge:init()
    self.objectDefaults = {} -- cached object defaults
    self._cacheQueue    = {}
end

function _ObjectBridge:_GetField(objectID, name)
    assert(self.getFuncs[name] ~= nil, "No such field: " .. tostring(name))
    return self.getFuncs[name](objectID)
end

function _ObjectBridge:CompareValues(v1, v2)
    local v1Type, v2Type = type(v1), type(v2)
    if v1Type ~= v2Type then
        return false
    elseif v1Type ~= "table" then
        return v1 == v2
    else
        local kCount1 = 0
        for k, v in pairs(v1) do
            kCount1 = kCount1 + 1
            if not self:CompareValues(v, v2[k]) then
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

function _ObjectBridge:_RemoveDefaults(objectID, values)
    local defName = self:_GetField(objectID, "defName")
    local defaults = self.objectDefaults[defName]
    if defaults then
        for name, _ in pairs(self.getFuncs) do
            local default = defaults[name]
            if default ~= nil then
                if self:CompareValues(values[name], default) then
--                     Spring.Echo(name, values[name], default)
                    values[name] = nil
--                 else
--                     Spring.Echo("DIFF", name, values[name], default)
--                     if type(default) == "table" then
--                         table.echo({values[name], default})
--                     end
                end
            end
        end
    end
end

function _ObjectBridge:_GetAllFields(objectID)
    local values = {}
    for name, _ in pairs(self.getFuncs) do
        values[name] = self:_GetField(objectID, name)
    end
    values.dir = nil -- rot is saved instead of dir to avoid duplicates
    self:_RemoveDefaults(objectID, values)
    return values
end

function _ObjectBridge:_SetField(objectID, name, value)
    assert(self.setFuncs[name] ~= nil, "No such field: " .. tostring(name))
    local applyDir = nil
    if name == "pos" then
        applyDir = self:_GetField(objectID, "rot")
    end
    self.setFuncs[name](objectID, value)
    -- ENGINE BUG
    -- If buildings are moved, their direction will be reset.
    -- An additional rotation must be applied after movement.
    if applyDir then
        self:_SetField(objectID, "rot", applyDir)
    end
end

function _ObjectBridge:_SetAllFields(objectID, object)
    local values = {}
    for name, value in pairs(object) do
        if self.setFuncs[name] ~= nil then
            self:_SetField(objectID, name, value)
        end
    end
end

function _ObjectBridge:Add(object)
    local objectID = self:CreateObject(object)

    self:_SetAllFields(objectID, object)
    return objectID
end

function _ObjectBridge:_CacheObject(objectID)
    -- cache defaults
    local defName = self:_GetField(objectID, "defName")
    local defaults = self.objectDefaults[defName]
    if not defaults then
        defaults = self:_GetAllFields(objectID)
        -- these fields don't have defaults
        defaults.pos = nil
        defaults.defName = nil
        defaults.team = nil
        self.objectDefaults[defName] = defaults
    end
end

function _ObjectBridge:_ObjectCreated(objectID)
    table.insert(self._cacheQueue, objectID)
end

function _ObjectBridge:_GameFrame()
    for _, objectID in pairs(self._cacheQueue) do
        self:_CacheObject(objectID)
    end
    self._cacheQueue = {}
end

function _ObjectBridge:Get(...)
    local params = {...}
    local objectID = params[1]
    if #params == 1 then
        if type(params[1]) ~= "table" then
            return self:_GetAllFields(objectID)
        else
            local objectIDs = params[1]
            local ret = {}
            for _, objectID in pairs(objectIDs) do
                ret[objectID] = self:_GetAllFields(objectID)
            end
            return ret
        end
    elseif #params == 2 then
        if type(params[2]) ~= "table" then
            local name = params[2]
            return self:_GetField(objectID, name)
        else
            local names = params[2]
            local ret = {}
            for _, name in pairs(names) do
                ret[name] = self:_GetField(objectID, name)
            end
            return ret
        end
    end
end

function _ObjectBridge:Set(...)
    local params = {...}
    local objectID = params[1]
    if #params == 2 then
        local object = params[2]
        self:_SetAllFields(objectID, object)
    elseif #params == 3 then
        local name = params[2]
        local value = params[3]
        self:_SetField(objectID, name, value)
    end
end