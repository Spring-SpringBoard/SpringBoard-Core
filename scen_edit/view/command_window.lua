CommandWindow = LCS.class{}

function CommandWindow:init()
    self.commandsPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 0,
        y = 20,
        width = "100%",
        height = "100%",
        autosize = true,
        resizeItems = false,
        centerItems = false,
    }
    self.list = List()
    self.list.CompareItems = function(obj, id1, id2)
        return id1 - id2
    end
    self.CommandWindowWindow = Window:New {
        parent = screen0,
        caption = "Command stack",
        x = screen0.width - 375,
        y = 550,
        resizable = true,
        width = 375,
        height = 300,
        children = {
            self.list.ctrl,
        }
    }
    self.count = 0
end

function CommandWindow:PushCommand(display)
    self.count = self.count + 1
    local id = self.count
    local lblVariableName = Label:New {
        caption = display,
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

function CommandWindow:PopCommand()
    self.list:RemoveRow(self.count)
    self.count = self.count - 1
end

function CommandWindow:ClearCommands()
    self.list:Clear()
    self.count = 0
end