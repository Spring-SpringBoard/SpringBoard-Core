HelloWorldCommand = AbstractCommand:extends{}

function HelloWorldCommand:init()
    self.className = "HelloWorldCommand"
end

function HelloWorldCommand:execute()
    Spring.Echo("Hello world")
end
