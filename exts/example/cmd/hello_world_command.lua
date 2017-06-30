HelloWorldCommand = Command:extends{}

function HelloWorldCommand:init(number)
    self.className = "HelloWorldCommand"
    self.number = number
end

function HelloWorldCommand:execute()
    Spring.Echo("Hello world: " .. tostring(self.number))
end
