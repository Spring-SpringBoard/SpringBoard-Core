CommandWindowModel = LCS.class{}

function CommandWindowModel:init()
    self.count = 0
    self.removedCount = 0
    self.undoCount = 0

    -- Callbacks for view updates
    self.onPushCommand = nil
    self.onUndoCommand = nil
    self.onRedoCommand = nil
    self.onRemoveFirstUndo = nil
    self.onRemoveFirstRedo = nil
    self.onClearUndoStack = nil
    self.onClearRedoStack = nil
    self.onButtonStateChanged = nil

    SB.commandManager:addListener(self)
end

function CommandWindowModel:CanUndo()
    return self.count - self.removedCount > self.undoCount
end

function CommandWindowModel:CanRedo()
    return self.undoCount > 0
end

function CommandWindowModel:CanClear()
    return self.count - self.removedCount > 0
end

function CommandWindowModel:UpdateButtonStates()
    local canUndo = self:CanUndo()
    local canRedo = self:CanRedo()
    local canClear = self:CanClear()
    if self.onButtonStateChanged then
        self.onButtonStateChanged(canUndo, canRedo, canClear)
    end
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

    if self.onPushCommand then
        self.onPushCommand(id, display)
    end

    self:UpdateButtonStates()
end

function CommandWindowModel:UndoCommand()
    Log.Debug("undo", self.count - self.undoCount)
    local id = self.count - self.undoCount

    if self.onUndoCommand then
        self.onUndoCommand(id)
    end

    self.undoCount = self.undoCount + 1
    self:UpdateButtonStates()
end

function CommandWindowModel:RedoCommand()
    Log.Debug("redo", self.count - self.undoCount + 1)
    local id = self.count - self.undoCount + 1

    if self.onRedoCommand then
        self.onRedoCommand(id)
    end

    self.undoCount = self.undoCount - 1
    self:UpdateButtonStates()
end

function CommandWindowModel:OnRemoveFirstUndo()
    Log.Debug("remundo", self.removedCount + 1)
    self.removedCount = self.removedCount + 1

    if self.onRemoveFirstUndo then
        self.onRemoveFirstUndo(self.removedCount)
    end
end

function CommandWindowModel:OnRemoveFirstRedo()
    Log.Debug(LOG.DEBUG, "remredo")

    if self.onRemoveFirstRedo then
        self.onRemoveFirstRedo(self.count)
    end

    self.count = self.count - 1
    self.undoCount = self.undoCount - 1
end

function CommandWindowModel:OnClearUndoStack()
    Log.Debug("clearundostack")

    if self.onClearUndoStack then
        self.onClearUndoStack()
    end

    while self.removedCount ~= self.count do
        self:OnRemoveFirstUndo()
    end
    Log.Debug("clearundostackend")
    self:UpdateButtonStates()
end

function CommandWindowModel:OnClearRedoStack()
    Log.Debug("clearredostack")

    if self.onClearRedoStack then
        self.onClearRedoStack()
    end

    while self.undoCount ~= 0 do
        self:OnRemoveFirstRedo()
    end
    Log.Debug("clearredostackend")
    self:UpdateButtonStates()
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
