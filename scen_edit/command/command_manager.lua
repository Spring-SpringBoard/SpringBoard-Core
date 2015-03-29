SCEN_EDIT_COMMAND_DIR = SCEN_EDIT_DIR .. "command/"

CommandManager = LCS.class{maxUndoSize = 1000, maxRedoSize = 1000}

function CommandManager:init(maxUndoSize, maxRedoSize)
    self.maxUndoSize = maxUndoSize
    self.maxRedoSize = maxRedoSize
    self.undoList = {}
    self.redoList = {}
    SCEN_EDIT.Include(SCEN_EDIT_COMMAND_DIR .. 'abstract_command.lua')
    SCEN_EDIT.Include(SCEN_EDIT_COMMAND_DIR .. 'undoable_command.lua')
    SCEN_EDIT.IncludeDir(SCEN_EDIT_COMMAND_DIR)
    --TODO: implement player lock
    self.playerLock = nil --if set, it defines the id of the only player who can do commands
    self.multipleCommandStack = {}
    self.multipleCommandMode = false
end

function CommandManager:_SafeCall(func)
    succ, result = xpcall(func, function(err)
        Spring.Log("scened", LOG.ERROR, "Error executing command.")
        Spring.Log("scened", LOG.ERROR, debug.traceback(err))
    end)
    if succ then 
        return result
    end
end

--entering this mode will add all future commands executed in the .multipleCommandStack (no command will go to the undoList)
--leaving this mode will group all the executed commands in one CompoundCommand and put it on the undoList
--undo/redo is disabled during this mode
function CommandManager:enterMultipleCommandMode()
    assert(not self.multipleCommandMode, "Trying to enter multiple command mode while already in it")
    self.multipleCommandMode = true
end

function CommandManager:leaveMultipleCommandMode()
    assert(self.multipleCommandMode, "Trying to leave multiple command mode while not in it")
    if self.multipleCommandStack[1].mergeCommand then
        -- there is a special command for merging
        local env = getfenv(1)
        cmd = env[self.multipleCommandStack[1].mergeCommand](self.multipleCommandStack)

        if cmd.onMerge then
            self:_SafeCall(function()
                cmd:onMerge()
            end)
        end
    else
        cmd = CompoundCommand(self.multipleCommandStack)
    end
    self.multipleCommandStack = {}
    self:undoListAdd(cmd)
    self.multipleCommandMode = false
    self:notify(cmd)
end

function CommandManager:notify(cmd)
    -- send display to the widget
    local display = cmd:display()
    self:execute(WidgetCommandExecuted(display), true)
end

--widget specifies whether the command should be executed in LuaUI(true) or LuaRules(false)
--if the command is to be executed in a different lua state than currently in, it will send the message to the proper state using the message mechanism
function CommandManager:execute(cmd, widget)
    assert(cmd, "Command is nil")
    if self.widget then
        if not widget then
            assert(cmd.className, "Command instance lacks className value")
            local msg = Message("command", cmd)
            SCEN_EDIT.messageManager:sendMessage(msg)
        else
            self:_SafeCall(function() 
                cmd:execute()
            end)
        end
    else
        if not widget then
            self:_SafeCall(function()
                cmd:execute()
            end)
            if cmd.unexecute then
                if self.multipleCommandMode then
                    table.insert(self.multipleCommandStack, cmd)
                else
                    self:undoListAdd(cmd)
                    self:notify(cmd)
                end
            end
        else
            assert(cmd.className, "Command instance lacks className value")
            local msg = Message("command", cmd)
            SCEN_EDIT.messageManager:sendMessage(msg)
        end
    end
end

function CommandManager:undoListAdd(cmd)
    table.insert(self.undoList, cmd)
    if #self.undoList > self.maxUndoSize then
        table.remove(self.undoList, 1)
    end
    self.redoList = {}
end

function CommandManager:redoListAdd(cmd)
    table.insert(self.redoList, cmd)
    if #self.redoList > self.maxRedoSize then
        table.remove(self.redoList, 1)
    end
end

function CommandManager:undo()
    if self.widget then
        local msg = Message("command", UndoCommand())
        SCEN_EDIT.messageManager:sendMessage(msg)
        return
    end
    assert(not self.multipleCommandMode, "Cannot undo while in multiple command mode")
    if #self.undoList < 1 then
        return
    end
    local cmd = table.remove(self.undoList, #self.undoList)
    self:_SafeCall(function() 
        cmd:unexecute()
        self:redoListAdd(cmd)
        self:execute(WidgetCommandUndo(), true)
    end)
end

function CommandManager:redo()
    if self.widget then
        local msg = Message("command", RedoCommand())
        SCEN_EDIT.messageManager:sendMessage(msg)
        return
    end
    assert(not self.multipleCommandMode, "Cannot redo while in multiple command mode")
    if #self.redoList < 1 then
        return
    end
    local cmd = table.remove(self.redoList, #self.redoList)
    self:_SafeCall(function() 
        cmd:execute()
        self:notify(cmd)
        table.insert(self.undoList, cmd)
    end)
end

function CommandManager:clearUndoRedoStack()
    self.undoList = {}
    self.redoList = {}
    self:_SafeCall(function() 
        self:execute(WidgetCommandClearUndoStack(), true)
    end)
end
