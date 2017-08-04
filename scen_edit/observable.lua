Observable = LCS.class{}

function Observable:init()
    self.listeners = {}
end

function Observable:addListener(listener)
    if listener == nil then
        Log.Error(debug.traceback())
        Log.Error("listener cannot be nil")
        return
    end
    table.insert(self.listeners, listener)
end

function Observable:removeListener(listener)
    for k, v in pairs(self.listeners) do
        if v == listener then
            table.remove(self.listeners, k)
        end
    end
end

function Observable:callListeners(func, ...)
    local listeners = Table.ShallowCopy(self.listeners)
    local args = {...}
    local n = select("#", ...)
    for _, listener in ipairs(self.listeners) do
        xpcall(
            function()
                local eventFunc = listener[func]
                if eventFunc then
                    eventFunc(listener, unpack(args, 1, n))
                end
            end,
            function(err)
                self:_PrintError(err)
            end
        )
    end
end

function Observable:_PrintError(err)
    Log.Error(debug.traceback(err, 2))
end
