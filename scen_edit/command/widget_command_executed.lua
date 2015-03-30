WidgetCommandExecuted = AbstractCommand:extends{}
WidgetCommandExecuted.className = "WidgetCommandExecuted"

function WidgetCommandExecuted:init(display)
    self.className = "WidgetCommandExecuted"
    self.display = display
end

function WidgetCommandExecuted:execute()
    SCEN_EDIT.view.commandWindow:PushCommand(self.display)
end

WidgetCommandUndo = AbstractCommand:extends{}
WidgetCommandUndo.className = "WidgetCommandUndo"

function WidgetCommandUndo:init()
    self.className = "WidgetCommandUndo"
end

function WidgetCommandUndo:execute()
    SCEN_EDIT.view.commandWindow:UndoCommand()
end

WidgetCommandRedo = AbstractCommand:extends{}
WidgetCommandRedo.className = "WidgetCommandRedo"

function WidgetCommandRedo:init()
    self.className = "WidgetCommandRedo"
end

function WidgetCommandRedo:execute()
    SCEN_EDIT.view.commandWindow:RedoCommand()
end

-- undo stack has been cleared
WidgetCommandClearUndoStack = AbstractCommand:extends{}
WidgetCommandClearUndoStack.className = "WidgetCommandClearUndoStack"

function WidgetCommandClearUndoStack:init()
    self.className = "WidgetCommandClearUndoStack"
end

function WidgetCommandClearUndoStack:execute()
    SCEN_EDIT.view.commandWindow:ClearUndoStack()
end

-- redo stack has been cleared
WidgetCommandClearRedoStack = AbstractCommand:extends{}
WidgetCommandClearRedoStack.className = "WidgetCommandClearRedoStack"

function WidgetCommandClearRedoStack:init()
    self.className = "WidgetCommandClearRedoStack"
end

function WidgetCommandClearRedoStack:execute()
    SCEN_EDIT.view.commandWindow:ClearRedoStack()
end

-- removed first undo
WidgetCommandRemoveFirstUndo = AbstractCommand:extends{}
WidgetCommandRemoveFirstUndo.className = "WidgetCommandRemoveFirstUndo"

function WidgetCommandRemoveFirstUndo:init()
    self.className = "WidgetCommandRemoveFirstUndo"
end

function WidgetCommandRemoveFirstUndo:execute()
    SCEN_EDIT.view.commandWindow:RemoveFirstUndo()
end

-- removed first redo
WidgetCommandRemoveFirstRedo = AbstractCommand:extends{}
WidgetCommandRemoveFirstRedo.className = "WidgetCommandRemoveFirstRedo"

function WidgetCommandRemoveFirstRedo:init()
    self.className = "WidgetCommandRemoveFirstRedo"
end

function WidgetCommandRemoveFirstRedo:execute()
    SCEN_EDIT.view.commandWindow:RemoveFirstRedo()
end