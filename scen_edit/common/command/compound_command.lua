CompoundCommand = LCS.class{}

function CompoundCommand:init(commands)
    self.className = "CompoundCommand"
    self.commands = commands
end

function CompoundCommand:execute()
    for i = 1, #self.commands do
        local command = self.commands[i]
        command:execute()
    end
end

function CompoundCommand:unexecute()
    for i = #self.commands, 1, -1 do
        local command = self.commands[i]
        command:unexecute()
    end
end
