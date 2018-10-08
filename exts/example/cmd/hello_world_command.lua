HelloWorldCommand = Command:extends{}
HelloWorldCommand.className = "HelloWorldCommand"

function HelloWorldCommand:init(number)
    self.number = number
end

function HelloWorldCommand:execute()
    Spring.Echo("Hello world: " .. tostring(self.number))
end
