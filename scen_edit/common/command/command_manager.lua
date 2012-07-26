local SCEN_EDIT_COMMON_DIR = "scen_edit/common/"
local SCEN_EDIT_COMMAND_DIR = SCEN_EDIT_COMMON_DIR .. "command/"

CommandManager = LCS.class{maxUndoSize = 100, maxRedoSize = 100}

function CommandManager:init(maxUndoSize, maxRedoSize)
    self.maxUndoSize = maxUndoSize
    self.maxRedoSize = maxRedoSize
    self.undoList = {}
    self.redoList = {}
end

function CommandManager:loadClasses()
    VFS.Include(SCEN_EDIT_COMMAND_DIR .. 'abstract_command.lua')
    VFS.Include(SCEN_EDIT_COMMAND_DIR .. 'undoable_command.lua')
    local files = VFS.DirList(SCEN_EDIT_COMMAND_DIR)
    for i = 1, #files do
        local file = files[i]
        if not file:find("abstract_command.lua") and not file:find("undoable_command.lua") then
            VFS.Include(file)
        end
    end
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
