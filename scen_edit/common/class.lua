function class(superclass)
    local cls = superclass and superclass() or {}
    cls.__index = cls
    cls.__super = superclass
    return setmetatable(cls, {__call = function (c, ...)
        instance = setmetatable({__class = cls}, cls)
        if cls.__init then
            cls.__init(instance, ...)
        end
        return instance
    end})
end

--[[
function class()
    local cls = {}
    cls.__index = cls
    return setmetatable(cls, {__call = function (c, ...)
        instance = setmetatable({}, cls)
        if cls.__init then
            cls.__init(instance, ...)
        end
        return instance
    end})
end
--]]

--[[function class(superclass, name)
    local cls = superclass and superclass() or {}
    cls.__name = name or ""
    cls.__super = superclass
    return setmetatable(cls, {__call = function (c, ...)
        self = setmetatable({__class = cls}, cls)
        if cls.__init then
            cls.__init(self, ...)
        end
        return self
    end})
end--]]
