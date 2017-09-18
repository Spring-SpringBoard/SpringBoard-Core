--- CompoundCommand class. Execute commands in sequence.
CompoundCommand = Command:extends{}


function CompoundCommand:init(commands)
    self.className = "CompoundCommand"
    self.commands = commands
    if self.commands then
        for _, cmd in pairs(self.commands) do
            if cmd._execute_unsynced then
                self._execute_unsynced = cmd._execute_unsynced
                break
            end
        end
    end
end

function CompoundCommand:execute()
    -- Execute commands in order
    for i = 1, #self.commands do
        local command = self.commands[i]
        command:execute()
    end
end

function CompoundCommand:unexecute()
    -- Execute commands in reverse order
    for i = #self.commands, 1, -1 do
        local command = self.commands[i]
        command:unexecute()
    end
end

function CompoundCommand:display()
    if #self.commands > 0 then
        return self.commands[1]:display()
    else
        return "CompoundCommand(empty)"
    end
end
