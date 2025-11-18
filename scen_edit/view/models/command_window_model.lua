CommandWindowModel = LCS.class{}

function CommandWindowModel:init()
    self.count = 0
    self.removedCount = 0
    self.undoCount = 0
    self.listeners = {}
end

function CommandWindowModel:Initialize()
    SB.commandManager:addListener(self)
end

function CommandWindowModel:AddListener(listener)
    table.insert(self.listeners, listener)
end

function CommandWindowModel:NotifyListeners(event, ...)
    for _, listener in ipairs(self.listeners) do
        if listener[event] then
            listener[event](listener, ...)
        end
    end
end

function CommandWindowModel:ExecuteUndo()
    SB.commandManager:execute(UndoCommand())
end

function CommandWindowModel:ExecuteRedo()
    SB.commandManager:execute(RedoCommand())
end

function CommandWindowModel:ExecuteClearHistory()
    SB.commandManager:execute(ClearUndoRedoCommand())
end

function CommandWindowModel:OnCommandExecuted(cmdIDs, isUndo, isRedo, display)
    if isUndo then
        self:UndoCommand()
    elseif isRedo then
        self:RedoCommand()
    else
        self:PushCommand(display)
    end
end

function CommandWindowModel:PushCommand(display)
    self.count = self.count + 1
    local id = self.count
    Log.Debug("do", id)
    self:NotifyListeners("OnPushCommand", id, display)
end

function CommandWindowModel:UndoCommand()
    Log.Debug("undo", self.count - self.undoCount)
    local cmdId = self.count - self.undoCount
    self.undoCount = self.undoCount + 1
    self:NotifyListeners("OnUndoCommand", cmdId)
end

function CommandWindowModel:RedoCommand()
    Log.Debug("redo", self.count - self.undoCount + 1)
    local cmdId = self.count - self.undoCount + 1
    self.undoCount = self.undoCount - 1
    self:NotifyListeners("OnRedoCommand", cmdId)
end

function CommandWindowModel:OnRemoveFirstUndo()
    Log.Debug("remundo", self.removedCount + 1)
    self.removedCount = self.removedCount + 1
    self:NotifyListeners("OnRemoveFirstUndo", self.removedCount)
end

function CommandWindowModel:OnRemoveFirstRedo()
    Log.Debug(LOG.DEBUG, "remredo")
    local cmdId = self.count
    self.count = self.count - 1
    self.undoCount = self.undoCount - 1
    self:NotifyListeners("OnRemoveFirstRedo", cmdId)
end

function CommandWindowModel:OnClearUndoStack()
    Log.Debug("clearundostack")
    while self.removedCount ~= self.count do
        self:OnRemoveFirstUndo()
    end
    Log.Debug("clearundostackend")
end

function CommandWindowModel:OnClearRedoStack()
    Log.Debug("clearredostack")
    while self.undoCount ~= 0 do
        self:OnRemoveFirstRedo()
    end
    Log.Debug("clearredostackend")
end
