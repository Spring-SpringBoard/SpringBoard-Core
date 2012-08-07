MessageManager = LCS.class{}

function MessageManager:init()
    self.prefix = "scen_edit"
    self.messageIdCount = 0
    self.callbacks = {}
    self.widget = false
    self.compress = false
end

function MessageManager:__encodeToString(message)
    local msg = table.show(message:serialize())
    if self.widget and self.compress then
        msg = VFS.ZlibCompress(msg)
    end
    return msg
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
        local size = #fullMessage
        local maxMsg = 50000
        if size < maxMsg then
            Spring.SendLuaRulesMsg(fullMessage)
        else
            local current = 1
            local msgPartIdx = 1
            local parts = math.floor(size / maxMsg + 1)
            Spring.Echo("send multi part msg: ".. tostring(parts))
            Spring.SendLuaRulesMsg(self.prefix .. "|" .. "startMsgPart" .. "|" .. parts)
            while current < size do
                local endIndex = math.min(current + maxMsg, size)
                local part = fullMessage:sub(current, endIndex)
                current = current + maxMsg
                local msg = self.prefix .. "|" .. "msgPart" .. "|" .. msgPartIdx .. "|" .. part
                Spring.SendLuaRulesMsg(msg)

                msgPartIdx = msgPartIdx + 1
            end
        end
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
