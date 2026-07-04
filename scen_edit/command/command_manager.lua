--- CommandManager module. Available globally as SB.commandManager.

SB.Include(Path.Join(SB.DIRS.SRC, 'command/command.lua'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'command'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'command/sync'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'command/project'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'command/textures'))

VFS.Include("libs_sb/json.lua", nil, VFS.ZIP)

--- CommandManager class
-- @type CommandManager
CommandManager = Observable:extends{maxUndoSize = 30, maxRedoSize = 30}

function CommandManager:init(maxUndoSize, maxRedoSize)
    self:super('init')

    self.maxUndoSize = maxUndoSize
    self.maxRedoSize = maxRedoSize
    self.undoList = {}
    self.redoList = {}
    --TODO: implement player lock
    self.playerLock = nil --if set, it defines the id of the only player who can do commands
    self.multipleCommandStack = {}
    self.multipleCommandMode = false
    self.idCount = 0

    self.__isWidget = Script.GetName() == "LuaUI"
    self.nativeCommandPromises = {}
end

-- Whether the native module owns this command's execution and undo/redo. A
-- CompoundCommand runs natively only when every command it groups does, so the
-- native side can execute and undo the whole group as one entry.
function CommandManager:runsNative(cmd)
    if cmd.className == "CompoundCommand" then
        if #cmd.commands == 0 then
            return false
        end
        for _, inner in ipairs(cmd.commands) do
            if not self:runsNative(inner) then
                return false
            end
        end
        return true
    end
    return cmd.__is_native == true or (cmd.is_A and cmd:is_A(NativeCommand))
end

function CommandManager:shouldInvokeNativeOnExecute(cmd)
    if cmd.className == "UndoCommand" or cmd.className == "RedoCommand" then
        return false
    end
    return true
end

function CommandManager:_SafeCall(func, label)
    local succ, result = xpcall(func, function(err)
        -- Report the actual error (and which command) instead of a generic line.
        local context = label and (": " .. tostring(label)) or "."
        local errText = tostring(err)
        Log.Error("[" .. Script.GetName() .. "] Error executing command" .. context)
        Log.Error(errText)
        -- On a C stack overflow the traceback itself recurses ("error in error
        -- handling"), so skip it; guard the rest in pcall for the same reason.
        if debug and errText ~= "C stack overflow" then
            local ok, trace = pcall(debug.traceback, err, 2)
            if ok and trace then
                Log.Error(trace)
            end
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
    local cmd
    local isMergeCommand = false
    if self.multipleCommandStack[1].mergeCommand then
        -- there is a special command for merging
        local env = getfenv(1)
        cmd = env[self.multipleCommandStack[1].mergeCommand](self.multipleCommandStack)
        isMergeCommand = true

        if cmd.onMerge then
            self:_SafeCall(function()
                cmd:onMerge()
            end, cmd.className .. ":onMerge")
        end
    else
        cmd = CompoundCommand(self.multipleCommandStack)
    end
    self.multipleCommandStack = {}
    self:undoListAdd(cmd)
    -- A plain CompoundCommand's inner commands already streamed to the native
    -- manager, which folds them into one history entry when the stream stops, so
    -- re-sending the group here would double-execute it. A merge command (e.g. the
    -- texture push-stack) drives native grouping itself, so it must be sent.
    if not self.__isWidget and isMergeCommand and self:runsNative(cmd) then
        self:invokeNativeCommand(cmd)
    end
    if not self.__isWidget then
        self:notify(cmd, cmdIDs)
    end
end

function CommandManager:notify(cmd, cmdIDs)
    -- send display to the widget
    local display = cmd:display()
    cmdIDs = cmdIDs or {cmd.__cmd_id}
    self:execute(WidgetCommandExecuted(display, cmdIDs), true)
end

function CommandManager:issueCommandID(cmd)
    assert(cmd.className, "Command instance lacks className value")
    if not cmd.__cmd_id then
        self.idCount = self.idCount + 1
        cmd.__cmd_id = self.idCount
    end
    return cmd.__cmd_id
end

function CommandManager:invokeNativeCommand(cmd)
    self:issueCommandID(cmd)
    local msg = Message("command", cmd)
    Spring.InvokeNativeModule(json.encode(msg:serialize()))
end

function CommandManager:executeNativeAsync(cmd, widget)
    assert(self.__isWidget, "executeNativeAsync must be called from LuaUI")
    assert(self:runsNative(cmd), "executeNativeAsync requires a native command: " .. tostring(cmd.className))

    self:issueCommandID(cmd)
    local promise = Promise()
    self.nativeCommandPromises[cmd.__cmd_id] = promise
    self:execute(cmd, widget)
    return promise
end

function CommandManager:completeNativeCommand(cmdID)
    local promise = self.nativeCommandPromises[cmdID]
    if not promise then
        Log.Debug("No pending native command promise for command id: " .. tostring(cmdID))
        return
    end
    self.nativeCommandPromises[cmdID] = nil
    promise:resolve(cmdID)
end

-- Sends the command to the other state (gadget <-> widget)
-- also returns the new command ID which can be used to track when it gets executed
function CommandManager:_SendCommand(cmd)
    self:issueCommandID(cmd)
    local msg = Message("command", cmd)
    SB.messageManager:sendMessage(msg)
    return cmd.__cmd_id
end

--- Execute a command
-- If the command is to be executed in a different Lua state than where this method is invoked from, it will be sent as a message to the proper state using the message mechanism.
-- @tparam command.Command Instance of a class that implements the Command interface.
-- @tparam[opt=false] boolean widget Specifies whether the command should be executed in LuaUI(true) or LuaRules(false).
-- @usage
-- SB.commandManager:execute(PrintMessageCommand("hello"))
function CommandManager:execute(cmd, widget)
    widget = not not widget
    Log.Debug(("[%s] %s, widget:%s"):format(Script.GetName(), cmd.className, tostring(not not widget)))
    assert(cmd, "Command is nil")
    return self:__execute(cmd, self.__isWidget == widget)
end

function CommandManager:__execute(cmd, isSameContext)
    if not isSameContext then
        return self:_SendCommand(cmd)
    end

    self:_SafeCall(function()
        if cmd._execute_unsynced and not self.__isWidget and not self:runsNative(cmd) then
            self:_SendCommand(cmd)
        else
            -- Drive the (single, shared) native module from the gadget only.
            -- Every command worth porting reaches the gadget (synced) first, so
            -- the native module sees it here; the widget pass stays Lua-only
            -- bookkeeping. (Pure widget-only commands — display text, unit say,
            -- draw — never reach the gadget, but they stay Lua anyway.) Sending
            -- from both states (e.g. SetMultipleCommandModeCommand, which re-runs
            -- in the widget) would hit the one native manager twice and desync
            -- its streaming/undo state.
            if not self.__isWidget and self:shouldInvokeNativeOnExecute(cmd) then
                self:invokeNativeCommand(cmd)
            end
            if not self:runsNative(cmd) then
                cmd:execute()
            end
        end
        -- Undoable if it defines a Lua :unexecute, or runs natively (Rust owns its
        -- undo stack; Lua only tracks the entry to drive native undo/redo).
        if (cmd.unexecute or self:runsNative(cmd)) and not cmd.blockUndo then
            if self.multipleCommandMode then
                table.insert(self.multipleCommandStack, cmd)
            else
                self:undoListAdd(cmd)
                if not self.__isWidget then
                    self:notify(cmd)
                end
            end
        end
    end, cmd.className)
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
        if not self.__isWidget then
            self:execute(WidgetCommandRemoveFirstUndo(), true)
        end
    end
    self:clearRedoStack()
end

function CommandManager:redoListAdd(cmd)
    table.insert(self.redoList, cmd)
    if #self.redoList > self.maxRedoSize then
        table.remove(self.redoList, 1)
        if not self.__isWidget then
            self:execute(WidgetCommandRemoveFirstRedo(), true)
        end
    end
end

function CommandManager:undo()
    assert(not self.multipleCommandMode, "Cannot undo while in multiple command mode")
    if #self.undoList < 1 then
        return
    end

    local cmd = table.remove(self.undoList, #self.undoList)
    self:_SafeCall(function()
        if self:runsNative(cmd) then
            -- Rust owns this command's execution and its undo stack; pop there
            -- (from the gadget only, as in the execute path). Lua's
            -- cmd:unexecute() would be a no-op (Lua never executed it).
            if not self.__isWidget then
                self:invokeNativeCommand(UndoCommand())
            end
        elseif not cmd._execute_unsynced or self.__isWidget then
            cmd:unexecute()
        else
            local msg = Message("command", UndoCommand())
            SB.messageManager:sendMessage(msg)
        end
        self:redoListAdd(cmd)
        if not self.__isWidget then
            self:execute(WidgetCommandUndo(), true)
        end
    end, cmd.className .. ":undo")
end

function CommandManager:redo()
    assert(not self.multipleCommandMode, "Cannot redo while in multiple command mode")
    if #self.redoList < 1 then
        return
    end

    local cmd = table.remove(self.redoList, #self.redoList)
    self:_SafeCall(function()
        if self:runsNative(cmd) then
            -- Rust owns this command; replay from its redo stack (gadget only,
            -- as above).
            if not self.__isWidget then
                self:invokeNativeCommand(RedoCommand())
            end
        elseif not cmd._execute_unsynced or self.__isWidget then
            cmd:execute()
        else
            --self:_SendCommand(cmd)
            local msg = Message("command", RedoCommand())
            SB.messageManager:sendMessage(msg)
        end
        if not self.__isWidget then
            self:execute(WidgetCommandRedo(), true)
        end
        table.insert(self.undoList, cmd)
    end, cmd.className .. ":redo")
end

function CommandManager:HandleCommandMessage(msg, widget)
    local cmd = self:_resolveCommand(msg.data)
    self:execute(cmd, widget)
end

function CommandManager:_resolveCommand(cmdTable)
    local cmd = {}
    if cmdTable.className then
        local env = getfenv(1)
        cmd = env[cmdTable.className]()
    end
    for k, v in pairs(cmdTable) do
        if type(v) == "table" then
            cmd[k] = self:_resolveCommand(v)
        else
            cmd[k] = v
        end
    end
    return cmd
end

------------------------------------------------
-- Listener definition
------------------------------------------------
CommandManagerListener = LCS.class.abstract{}

function CommandManagerListener:OnCommandExecuted(cmdIDs, isUndo, isRedo, display)
end

function CommandManagerListener:OnClearUndoStack()
end

function CommandManagerListener:OnClearRedoStack()
end

function CommandManagerListener:OnRemoveFirstUndo()
end

function CommandManagerListener:OnRemoveFirstRedo()
end
------------------------------------------------
-- End listener definition
------------------------------------------------
