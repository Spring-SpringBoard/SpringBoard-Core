MergedCommand = Command:extends{}
MergedCommand.className = "MergedCommand"

function MergedCommand:init(cmds)
    self.cmds = cmds
end

function MergedCommand:onMerge()
    self.cmd = self.cmds[1]
    self.displayText = self.cmd:display()
    if self.cmd._execute_unsynced and Script.GetName() == "LuaRules" then
        self._execute_unsynced = true
        self.cmd = nil
        return
    end

    self.cmd.opts = self.cmds[#self.cmds].opts
    self.cmd.old = self.cmds[1].old
    for i = #self.cmds, 2, -1 do
        local c = self.cmds[i]
        Table.Merge(self.cmd.opts, c.opts)
    end
    for i = 2, #self.cmds do
        local c = self.cmds[i]
        -- Spring.Echo(not not self.cmd.old, not not c.opts.old, i)
        Table.Merge(self.cmd.old, c.old)
    end
end

function MergedCommand:execute()
    if self._execute_unsynced then
        SB.commandManager:execute(RedoCommand(), true)
        return
    end
    self.cmd:execute()
end

function MergedCommand:unexecute()
    if self._execute_unsynced then
        SB.commandManager:execute(UndoCommand(), true)
        return
    end
    self.cmd:unexecute()
end

function MergedCommand:display()
    return self.displayText
end
