Observable = LCS.class{}

function Observable:init()
    self.listeners = {}
end

function Observable:addListener(listener)
    table.insert(self.listeners, listener)
end

function Observable:removeListener(listener)
    for k, v in pairs(self.listeners) do
        if v == listener then
            table.remove(self.listeners, k)
       --     Spring.Echo("removed")
        end
    end

    --table.remove(self.listeners, listener)
end

function Observable:callListeners(func, ...)
    for i = 1, #self.listeners do
        local listener = self.listeners[i]
        listener[func](listener, ...)
    end
end
