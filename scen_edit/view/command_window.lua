CommandWindow = LCS.class{}

function CommandWindow:init()
    local children = {
        Button:New {
            x = 10,
            y = 15,
            height = 40,
            width = 40,
            caption = '',
            tooltip = "Undo (Ctrl+Z)",
            OnClick = {
                function()
                    SB.commandManager:execute(UndoCommand())
                end
            },
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "anticlockwise-rotation.png",
                    height = 20,
                    width = 20,
                    margin = {0, 0, 0, 0},
                    x = 0,
                },
            },
        },
        Button:New {
            x = 50,
            y = 15,
            height = 40,
            width = 40,
            caption = '',
            tooltip = "Redo (Ctrl+R)",
            OnClick = {
                function()
                    SB.commandManager:execute(RedoCommand())
                end
            },
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "clockwise-rotation.png",
                    height = 20,
                    width = 20,
                    margin = {0, 0, 0, 0},
                    x = 0,
                },
            },
        },
        Button:New {
            x = 90,
            y = 15,
            height = 40,
            width = 40,
            caption = '',
            tooltip = "Clear undo-redo stack",
            OnClick = {
                function()
                    SB.commandManager:execute(ClearUndoRedoCommand())
                end
            },
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "cancel.png",
                    height = 20,
                    width = 20,
                    margin = {0, 0, 0, 0},
                    x = 0,
                },
            },
        },
    }

    self.list = List()
    self.list.CompareItems = function(obj, id1, id2)
        return id1 - id2
    end

Spring.Echo("self.list.ctrl", self.list.ctrl, type(self.list.ctrl))
    table.insert(children, self.list.ctrl)

    self.window = Window:New {
        parent = screen0,
        caption = "",
        right = 500 + 375,
        bottom = 0,
        resizable = false,
        draggable = false,
        width = 400,
        height = 80,
        padding = {5,5,0,0},
        children = children,
    }
    self.list.ctrl:SetPos(140, nil, 400 - 140 - 10)

    self.count = 0
    self.removedCount = 0
    self.undoCount = 0
end

function CommandWindow:PushCommand(display)
    self.count = self.count + 1
    local id = self.count
    Log.Debug("do", id)
    local lblVariableName = Label:New {
        caption = tostring(id) .. " " .. display,
        y = 0,
        height= 45,
        x = 0,
        width = 350,
        align = 'center',
        id = id,
        valign = 'center',
    }
    self.list:AddRow({lblVariableName}, id)
end

function CommandWindow:UndoCommand()
    Log.Debug("undo", self.count - self.undoCount)
    local row = self.list:GetRowItems(self.count - self.undoCount)
    local lbl = row[1]
    lbl._oldcaption = lbl.caption
    lbl:SetCaption("\255\100\100\100" .. lbl.caption .. "\b")
    lbl:Invalidate()

    self.undoCount = self.undoCount + 1
end

function CommandWindow:RedoCommand()
    Log.Debug("redo", self.count - self.undoCount + 1)
    local row = self.list:GetRowItems(self.count - self.undoCount + 1)
    local lbl = row[1]
    lbl:SetCaption(lbl._oldcaption)
    lbl:Invalidate()
    lbl._oldcaption = nil

    self.undoCount = self.undoCount - 1
end

function CommandWindow:RemoveFirstUndo()
    Log.Debug("remundo", self.removedCount + 1)
    self.removedCount = self.removedCount + 1
    self.list:RemoveRow(self.removedCount)
end

function CommandWindow:RemoveFirstRedo()
    Log.Debug(LOG.DEBUG, "remredo")
    self.list:RemoveRow(self.count)
    self.count = self.count - 1
    self.undoCount= self.undoCount - 1
end

function CommandWindow:ClearUndoStack()
    Log.Debug("clearundostack")
    while self.removedCount ~= self.count do
        self:RemoveFirstUndo()
    end
    Log.Debug("clearundostackend")
end

function CommandWindow:ClearRedoStack()
    Log.Debug("clearredostack")
    while self.undoCount ~= 0 do
        self:RemoveFirstRedo()
    end
    Log.Debug("clearredostackend")
end
