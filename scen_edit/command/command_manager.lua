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
end

function CommandManager:execute(cmd, widget)
    assert(cmd, "Command is nil")
    if self.widget then
        if not widget then
            assert(cmd.className, "Command instance lacks className")
            local msg = Message("command", cmd)
--            Spring.Echo('msg')
            SCEN_EDIT.messageManager:sendMessage(msg)
--            Spring.Echo('send')
        else
            cmd:execute()
        end
    else
        if not widget then
            cmd:execute()
            if not cmd.unexecute then
--                Spring.Echo("not undoable")
                return
            end
--            Spring.Echo("undoable")
            table.insert(self.undoList, cmd)
            if #self.undoList > self.maxUndoSize then
                table.remove(self.undoList, 1)
            end
            self.redoList = {}
        else
            assert(cmd.className, "Command instance lacks className")
            local msg = Message("command", cmd)
            SCEN_EDIT.messageManager:sendMessage(msg)
        end
    end
end

function CommandManager:undo()
    if self.widget then
        local msg = Message("command", UndoCommand())
        SCEN_EDIT.messageManager:sendMessage(msg)
        return
    end
    if #self.undoList < 1 then
        return
    end
--    Spring.Echo("Undo")
    local cmd = table.remove(self.undoList, #self.undoList)
    cmd:unexecute()
    table.insert(self.redoList, cmd)
    if #self.redoList > self.maxRedoSize then
        table.remove(self.redoList, 1)
    end
end

function CommandManager:redo()
    if self.widget then
        local msg = Message("command", RedoCommand())
        SCEN_EDIT.messageManager:sendMessage(msg)
        return
    end
    if #self.redoList < 1 then
        return
    end
--    Spring.Echo("Redo")
    local cmd = table.remove(self.redoList, #self.redoList)
    cmd:execute()
    table.insert(self.undoList, cmd)
end

function CommandManager:clearUndoRedoStack()
    self.undoList = {}
    self.redoList = {}
end
