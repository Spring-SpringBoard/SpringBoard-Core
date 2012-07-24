MessageManager = LCS.class{}

function MessageManager:init()
    self.prefix = "scen_edit"
    self.messageIdCount = 0
    self.callbacks = {}
    self.widget = false
end

function MessageManager:__encodeToString(message)
    return table.show(message:serialize())
end

function MessageManager:sendMessage(message, callback)
    self.messageIdCount = self.messageIdCount + 1
    message.id = self.messageIdCount

    local messageType = "sync"
    if callback ~= nil then
        messageType = "async"
        self.callbacks[message.id] = callback
    end

    local fullMessage = self.prefix .. "|" .. messageType .. "|" .. self:__encodeToString(message)
    if self.widget then
        Spring.SendLuaRulesMsg(fullMessage)
    else
        SendToUnsynced("toWidget", fullMessage)
    end
end

function MessageManager:recieveMessage(message, messageType)
    if messageType == "async" and self.callbacks[message.id] ~= nil then
        self.callbacks[message.id](message)
        self.callbacks[message.id] = nil
    end
end
