BridgeTestAckCommand = Command:extends{}
BridgeTestAckCommand.className = "BridgeTestAckCommand"

function BridgeTestAckCommand:init(side, token)
    self.side = side
    self.token = token
end

function BridgeTestAckCommand:execute()
    Spring.InvokeNativeModule(json.encode({
        tag = "bridge_test_ack",
        data = {
            side = self.side,
            token = self.token,
            luaState = Script.GetName(),
        },
    }))
end
