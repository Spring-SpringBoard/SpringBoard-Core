SaveMapCommand = NativeCommand:extends{}
SaveMapCommand.className = "SaveMapCommand"

function SaveMapCommand:init(path)
    self.path = path
end
