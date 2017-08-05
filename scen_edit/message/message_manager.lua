MessageManager = LCS.class{}

function MessageManager:init()
    self.prefix = "scen_edit"
    self.messageIDCount = 0
    self.callbacks = {}
    self.__isWidget = Script.GetName() == "LuaUI"
    self.compress = true
end

function MessageManager:__encodeToString(message)
    local msg = table.show(message:serialize())
    if self.__isWidget and self.compress then
        local newMsg = SB.ZlibCompress(msg)
        -- FIXME: obvious slowdown, but detects weird Spring bugs
        assert(SB.ZlibDecompress(newMsg) == msg)
        msg = newMsg
    end
    return msg
end

function MessageManager:sendMessage(message, callback)
    self.messageIDCount = self.messageIDCount + 1
    message.id = self.messageIDCount

    local messageType = "sync"
    if callback ~= nil then
        messageType = "async"
        self.callbacks[message.id] = callback
    end

    local fullMessage = self.prefix .. "|" .. messageType .. "|" .. self:__encodeToString(message)
    if self.__isWidget then
        local size = #fullMessage
        local maxMsgSize = 50000
        if size < maxMsgSize then
            Spring.SendLuaRulesMsg(fullMessage)
        else
            local current = 1
            local msgPartIdx = 1
            local parts = math.floor(size / maxMsgSize + 1)
            --Log.Notice("send multi part msg: ".. tostring(parts))
            Spring.SendLuaRulesMsg(self.prefix .. "|" .. "startMsgPart" .. "|" .. parts)
            while current < size do
                local endIndex = math.min(current + maxMsgSize, size)
                local part = fullMessage:sub(current, endIndex)
                current = current + maxMsgSize + 1
                local msg = self.prefix .. "|" .. "msgPart" .. "|" .. tostring(msgPartIdx) .. "|" .. part
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
