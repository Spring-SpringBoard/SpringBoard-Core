CommandWindow = LCS.class{}

function CommandWindow:init(parent, model)
    self.model = model or CommandWindowModel()
    self.list = List()
    self.list.CompareItems = function(obj, id1, id2)
        return id1 - id2
    end

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
            tooltip = "Redo (Ctrl+R)",
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

    self.model:AddListener(self)
    self.model:Initialize()
end

-- UI update callbacks from model
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

function CommandWindow:OnUndoCommand(cmdId)
    local row = self.list:GetRowItems(cmdId)
    local lbl = row[1]
    lbl._oldcaption = lbl.caption
    lbl:SetCaption("\255\88\143\143" .. lbl.caption .. "\b")
    lbl:Invalidate()
end

function CommandWindow:OnRedoCommand(cmdId)
    local row = self.list:GetRowItems(cmdId)
    local lbl = row[1]
    lbl:SetCaption(lbl._oldcaption)
    lbl:Invalidate()
    lbl._oldcaption = nil
end

function CommandWindow:OnRemoveFirstUndo(cmdId)
    self.list:RemoveRow(cmdId)
end

function CommandWindow:OnRemoveFirstRedo(cmdId)
    self.list:RemoveRow(cmdId)
end
