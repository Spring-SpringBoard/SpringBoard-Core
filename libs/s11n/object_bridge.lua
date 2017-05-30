_ObjectBridge = LCS.class{}

function _ObjectBridge:init()
    self.objectDefaults = {} -- cached object defaults
    self._cacheQueue    = {}
end

function _ObjectBridge:_GetField(objectID, name)
    assert(self.getFuncs[name] ~= nil, "No such field: " .. tostring(name))
    return self.getFuncs[name](objectID)
end

function _ObjectBridge:_CompareValues(v1, v2)
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

function _ObjectBridge:_RemoveDefaults(objectID, values)
    local defName = self:_GetField(objectID, "defName")
    local defaults = self.objectDefaults[defName]
    if defaults then
        for name, _ in pairs(self.getFuncs) do
            local default = defaults[name]
            if default ~= nil then
                if self:_CompareValues(values[name], default) then
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

function _ObjectBridge:_CacheObject(objectID)
--     -- cache defaults
--     local defName = self:_GetField(objectID, "defName")
--     local defaults = self.objectDefaults[defName]
--     if not defaults then
--         defaults = self:_GetAllFields(objectID)
--         -- these fields don't have defaults
--         defaults.pos = nil
--         defaults.defName = nil
--         defaults.team = nil
--         self.objectDefaults[defName] = defaults
--     end
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

local function ReportObjectCreationFail(object)
    Spring.Log("SpringBoard", "error", "Failed to create object: ")
    if type(object) == "table" then
        table.echo(object)
    else
        Spring.Echo(object)
    end
    return
end

-------------------------------------------------------
-- API
-------------------------------------------------------
-- s11n:Add(object)
-- s11n:Add(objects)
function _ObjectBridge:Add(input)
    -- If input is an array and there isn't a .defName, then this is
    -- probably an array of objects to be created
    -- Create multiple objects
    -- s11n:Add(objects)
    if #input > 0 and not input.defName then
        local objectIDs = {}
        for _, object in pairs(input) do
            local objectID = self:CreateObject(object)
            if not objectID then
                ReportObjectCreationFail(object)
                return
            end
            local team = object.team
            object.team = nil
            self:_SetAllFields(objectID, object)
            object.team = team
            table.insert(objectIDs, objectID)
        end
        return objectIDs
    -- Create one object
    -- s11n:Add(object)
    else
        local objectID = self:CreateObject(input)
        if not objectID then
            ReportObjectCreationFail(input)
            return
        end
        local team = input.team
        input.team = nil
        self:_SetAllFields(objectID, input)
        input.team = team
        return objectID
    end
end

-- s11n:Get()
-- s11n:Get(objectID)
-- s11n:Get(objectIDs)
-- s11n:Get(objectID, key)
-- s11n:Get(objectID, keys)
-- s11n:Get(objectIDs, key)
-- s11n:Get(objectIDs, keys)
function _ObjectBridge:Get(...)
    local params = {...}

    local paramsCount = #params
    -- Return all objects
    -- s11n:Get()
    if paramsCount == 0 then
        local ret = {}
        for _, objectID in pairs(self:GetAllObjectIDs()) do
            ret[objectID] = self:_GetAllFields(objectID)
        end
        return ret
    -- No keys are specified
    elseif paramsCount == 1 then
        -- One object
        -- s11n:Get(objectID)
        if type(params[1]) ~= "table" then
            return self:_GetAllFields(params[1])
        -- Multiple objects
        -- s11n:Get(objectIDs)
        else
            local ret = {}
            for _, objectID in pairs(params[1]) do
                ret[objectID] = self:_GetAllFields(objectID)
            end
            return ret
        end
    -- Keys are specified
    elseif paramsCount == 2 then
        -- One object
        if type(params[1]) ~= "table" then
            -- One key
            -- s11n:Get(objectID, key)
            if type(params[2]) ~= "table" then
                return self:_GetField(params[1], params[2])
            -- Multiple keys
            -- s11n:Get(objectID, keys)
            else
                local ret = {}
                for _, key in pairs(params[2]) do
                    ret[key] = self:_GetField(params[1], key)
                end
                return ret
            end
        -- Multiple objects
        else
            -- One key
            -- s11n:Get(objectIDs, key)
            if type(params[2]) ~= "table" then
                local ret = {}
                for _, objectID in pairs(params[1]) do
                    ret[objectID] = self:_GetField(objectID, params[2])
                end
                return ret
            -- Multiple keys
            -- s11n:Get(objectIDs, keys)
            else
                local ret = {}
                for _, objectID in pairs(params[1]) do
                    local objectKeys = {}
                    for _, key in pairs(params[2]) do
                        ret[key] = self:_GetField(objectID, key)
                    end
                    ret[objectID] = objectKeys
                end
                return ret
            end
        end
    end
end

-- s11n:Set(object)
-- s11n:Set(objects)
-- s11n:Set(objectID, key, value)
-- s11n:Set(objectID, keys, values)
-- s11n:Set(objectIDs, key, value)
-- s11n:Set(objectIDs, keys, values)
function _ObjectBridge:Set(...)
    local params = {...}
    local paramsCount = #params

    -- Set object or objects
    if paramsCount == 1 then
        -- Multiple object
        -- s11n:Set(objects)
        if #params[1] > 0 and not params[1].objectID then
            for _, object in pairs(params[1]) do
                local objectID = object.id
                object.objectID = nil
                self:_SetAllFields(object.id, object)
                object.objectID = objectID
            end
        -- One object
        -- s11n:Set(object)
        else
            local objectID = params[1].id
            params[1].objectID = nil
            self:_SetAllFields(objectID, params[1])
            params[1].objectID = objectID
        end
    -- Set objectID, keyValueTable
    elseif paramsCount == 2 then
        -- One object
        -- s11n:Set(objectID, keyValueTable)
        if type(params[1]) ~= "table" then
            -- One object
            self:_SetAllFields(params[1], params[2])
        -- Multiple objects
        -- s11n:Set(objectIDs, keyValueTable)
        else
            for _, objectID in pairs(params[1]) do
                self:_SetAllFields(objectID, params[2])
            end
        end
    -- Set keys-values
    elseif paramsCount == 3 then
        -- One key
        if type(params[2]) ~= "table" then
            -- One object
            -- s11n:Set(objectID, key, value)
            if type(params[1]) == "number" then
                self:_SetField(params[1], params[2], params[3])
            -- Multiple object
            -- s11n:Set(objectIDs, key, value)
            else
                for _, objectID in pairs(params[1]) do
                    self:_SetField(objectID, params[2], params[3])
                end
            end
        -- Multiple keys
        else
            -- One object
            -- s11n:Set(objectID, keys, values)
            if type(params[1]) == "number" then
                local keys, values = params[2], params[3]
                for i = 1, #keys do
                    local key, value = keys[i], values[i]
                    self:_SetField(params[1], key, value)
                end
            -- Multiple object
            -- s11n:Set(objectIDs, keys, values)
            else
                local keys, values = params[2], params[3]
                for _, objectID in pairs(params[1]) do
                    for i = 1, #keys do
                        local key, value = keys[i], values[i]
                        self:_SetField(objectID, key, value)
                    end
                end
            end
        end
    else
        table.echo(params)
        error("Invalid parameters: " .. tostring(paramsCount) .. " for s11n:Set")

    end
end
-------------------------------------------------------
-- End API
-------------------------------------------------------
