SB_COMMAND_DIR = Path.Join(SB_DIR, "command/")
SB_COMMAND_SYNC_DIR = Path.Join(SB_COMMAND_DIR, "sync/")

SB.Include(Path.Join(SB_COMMAND_DIR, 'command.lua'))
SB.IncludeDir(SB_COMMAND_DIR)
SB.IncludeDir(SB_COMMAND_SYNC_DIR)

CommandManager = LCS.class{maxUndoSize = 30, maxRedoSize = 30}

function CommandManager:init(maxUndoSize, maxRedoSize)
    self.maxUndoSize = maxUndoSize
    self.maxRedoSize = maxRedoSize
    self.undoList = {}
    self.redoList = {}
    --TODO: implement player lock
    self.playerLock = nil --if set, it defines the id of the only player who can do commands
    self.multipleCommandStack = {}
    self.multipleCommandMode = false
    self.idCount = 0
end

function CommandManager:_SafeCall(func)
    succ, result = xpcall(func, function(err)
        Log.Error("Error executing command. ")
        if debug then
            Log.Error(debug.traceback(err))
        else
            Log.Error(err)
        end
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
    self.multipleCommandMode = false

    if #self.multipleCommandStack == 0 then
        return
    end
    local cmdIDs = {} -- send a list of executed commands
    for _, cmd in pairs(self.multipleCommandStack) do
        table.insert(cmdIDs, cmd.__cmd_id)
    end
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
    self:notify(cmd, cmdIDs)
end

function CommandManager:notify(cmd, cmdIDs)
    -- send display to the widget
    local display = cmd:display()
    cmdIDs = cmdIDs or {cmd.__cmd_id}
    self:execute(WidgetCommandExecuted(display, cmdIDs), true)
end

-- Sends the command to the other state (gadget <-> widget)
-- also returns the new command ID which can be used to track when it gets executed
function CommandManager:_SendCommand(cmd)
    assert(cmd.className, "Command instance lacks className value")
    self.idCount = self.idCount + 1
    cmd.__cmd_id = self.idCount
    local msg = Message("command", cmd)
    SB.messageManager:sendMessage(msg)
    return cmd.__cmd_id
end

--widget specifies whether the command should be executed in LuaUI(true) or LuaRules(false)
--if the command is to be executed in a different lua state than currently in, it will send the message to the proper state using the message mechanism
function CommandManager:execute(cmd, widget)
    assert(cmd, "Command is nil")
    if self.widget then -- from widget
        if not widget then
            return self:_SendCommand(cmd)
        else
            self:_SafeCall(function()
                cmd:execute()
            end)
        end
    else -- from gadget
        if not widget then
            self:_SafeCall(function()
                cmd:execute()
                if cmd.unexecute and not cmd.blockUndo then
                    if self.multipleCommandMode then
                        table.insert(self.multipleCommandStack, cmd)
                    else
                        self:undoListAdd(cmd)
                        self:notify(cmd)
                    end
                end
            end)
        else
            return self:_SendCommand(cmd)
        end
    end
end

function CommandManager:clearUndoStack()
    if #self.undoList > 0 then
        self.undoList = {}
        self:execute(WidgetCommandClearUndoStack(), true)
    end
end

function CommandManager:clearRedoStack()
    if #self.redoList > 0 then
        self.redoList = {}
        self:execute(WidgetCommandClearRedoStack(), true)
    end
end

function CommandManager:clearUndoRedoStack()
    self:clearUndoStack()
    self:clearRedoStack()
end

function CommandManager:undoListAdd(cmd)
    table.insert(self.undoList, cmd)
    if #self.undoList > self.maxUndoSize then
        table.remove(self.undoList, 1)
        self:execute(WidgetCommandRemoveFirstUndo(), true)
    end
    self:clearRedoStack()
end

function CommandManager:redoListAdd(cmd)
    table.insert(self.redoList, cmd)
    if #self.redoList > self.maxRedoSize then
        table.remove(self.redoList, 1)
        self:execute(WidgetCommandRemoveFirstRedo(), true)
    end
end

function CommandManager:undo()
    if self.widget then
        local msg = Message("command", UndoCommand())
        SB.messageManager:sendMessage(msg)
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
        SB.messageManager:sendMessage(msg)
        return
    end
    assert(not self.multipleCommandMode, "Cannot redo while in multiple command mode")
    if #self.redoList < 1 then
        return
    end
    local cmd = table.remove(self.redoList, #self.redoList)
    self:_SafeCall(function()
        cmd:execute()
        self:execute(WidgetCommandRedo(), true)
        table.insert(self.undoList, cmd)
    end)
end
