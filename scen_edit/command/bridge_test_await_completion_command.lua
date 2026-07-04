BridgeTestAwaitCompletionCommand = Command:extends{}
BridgeTestAwaitCompletionCommand.className = "BridgeTestAwaitCompletionCommand"

function BridgeTestAwaitCompletionCommand:init(cmdID, token)
    self.cmdID = cmdID
    self.token = token
end

function BridgeTestAwaitCompletionCommand:execute()
    local token = self.token
    local promise = Promise()
    SB.commandManager.nativeCommandPromises[self.cmdID] = promise
    promise:next(function()
        Spring.InvokeNativeModule(json.encode({
            tag = "bridge_test_ack",
            data = {
                side = "async",
                token = token,
                luaState = Script.GetName(),
            },
        }))
    end)
end
