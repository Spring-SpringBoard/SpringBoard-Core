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
    SCEN_EDIT.view.commandWindow:PopCommand()
end

WidgetCommandClearUndoStack = AbstractCommand:extends{}
WidgetCommandClearUndoStack.className = "WidgetCommandClearUndoStack"

function WidgetCommandClearUndoStack:init()
    self.className = "WidgetCommandClearUndoStack"
end

function WidgetCommandClearUndoStack:execute()
    SCEN_EDIT.view.commandWindow:ClearCommands()
end