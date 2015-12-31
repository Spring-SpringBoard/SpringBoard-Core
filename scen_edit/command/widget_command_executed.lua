WidgetCommandExecuted = AbstractCommand:extends{}
WidgetCommandExecuted.className = "WidgetCommandExecuted"

function UpdateViews()
    if SCEN_EDIT.unitPropertyWindow then
        SCEN_EDIT.unitPropertyWindow:CommandExecuted()
    end
    if SCEN_EDIT.collisionView then
        SCEN_EDIT.collisionView:CommandExecuted()
    end
end

function WidgetCommandExecuted:init(display, cmdIDs)
    self.className = "WidgetCommandExecuted"
    self.display = display
    self.cmdIDs = cmdIDs
end

function WidgetCommandExecuted:execute()
    SCEN_EDIT.view.commandWindow:PushCommand(self.display)
    UpdateViews()
    local currentState = SCEN_EDIT.stateManager:GetCurrentState()
    if currentState:is_A(BrushObjectState) then
        for _, cmdID in pairs(self.cmdIDs) do
            currentState:CommandExecuted(cmdID)
        end
    end
end

WidgetCommandUndo = AbstractCommand:extends{}
WidgetCommandUndo.className = "WidgetCommandUndo"

function WidgetCommandUndo:init()
    self.className = "WidgetCommandUndo"
end

function WidgetCommandUndo:execute()
    SCEN_EDIT.view.commandWindow:UndoCommand()
    UpdateViews()
end

WidgetCommandRedo = AbstractCommand:extends{}
WidgetCommandRedo.className = "WidgetCommandRedo"

function WidgetCommandRedo:init()
    self.className = "WidgetCommandRedo"
end

function WidgetCommandRedo:execute()
    SCEN_EDIT.view.commandWindow:RedoCommand()
    UpdateViews()
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
	SCEN_EDIT.delayGL(function()
		SCEN_EDIT.model.textureManager:RemoveFirst()
	end)
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