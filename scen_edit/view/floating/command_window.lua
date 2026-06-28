SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/command_window_model.lua'))

CommandWindow = LCS.class{}

function CommandWindow:init(parent)
    self.model = CommandWindowModel()

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
                    self.model:ExecuteUndo()
                end
            },
            children = {
                Image:New {
                    file = Path.Join(SB.DIRS.IMG, 'anticlockwise-rotation.png'),
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
            tooltip = "Redo (Ctrl+Y)",
            OnClick = {
                function()
                    self.model:ExecuteRedo()
                end
            },
            children = {
                Image:New {
                    file = Path.Join(SB.DIRS.IMG, 'clockwise-rotation.png'),
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
                    self.model:ExecuteClearHistory()
                end
            },
            children = {
                Image:New {
                    file = Path.Join(SB.DIRS.IMG, 'cancel.png'),
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

    table.insert(children, self.list.ctrl)

    self.window = Control:New {
        parent = parent,
        caption = "",
        right = 0,
        bottom = 3,
        width = 400,
        height = "100%",
        padding = {5,5,0,0},
        children = children,
    }
    self.list.ctrl:SetPos(140, nil, 400 - 140 - 10)

    -- Register view callbacks with model
    self.model.onPushCommand = function(id, display)
        self:OnPushCommand(id, display)
    end
    self.model.onUndoCommand = function(id)
        self:OnUndoCommand(id)
    end
    self.model.onRedoCommand = function(id)
        self:OnRedoCommand(id)
    end
    self.model.onRemoveFirstUndo = function(removedCount)
        self:OnRemoveFirstUndo(removedCount)
    end
    self.model.onRemoveFirstRedo = function(count)
        self:OnRemoveFirstRedo(count)
    end
end

function CommandWindow:OnPushCommand(id, display)
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

function CommandWindow:OnUndoCommand(id)
    local row = self.list:GetRowItems(id)
    local lbl = row[1]
    lbl._oldcaption = lbl.caption
    lbl:SetCaption("\255\88\143\143" .. lbl.caption .. "\b")
    lbl:Invalidate()
end

function CommandWindow:OnRedoCommand(id)
    local row = self.list:GetRowItems(id)
    local lbl = row[1]
    lbl:SetCaption(lbl._oldcaption)
    lbl:Invalidate()
    lbl._oldcaption = nil
end

function CommandWindow:OnRemoveFirstUndo(removedCount)
    self.list:RemoveRow(removedCount)
end

function CommandWindow:OnRemoveFirstRedo(count)
    self.list:RemoveRow(count)
end
