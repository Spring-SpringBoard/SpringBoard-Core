CommandWindow = LCS.class{}

function CommandWindow:init()
    self.commandsPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 0,
        y = 0,
        width = "100%",
        height = "100%",
        autosize = true,
        resizeItems = false,
        centerItems = false,
    }
    self.CommandWindowWindow = Window:New {
        parent = screen0,
        caption = "Command Window",
        x = screen0.width - 375,
        y = 550,
		resizable = true,
        width = 375,
        height = 300,
        children = {
            ScrollPanel:New {
                y = 20,
                width = "100%",
                bottom = 10,
                children = { 
                    self.commandsPanel,
                },
                verticalSmartScroll = true,
            },
        }
    }
end

function CommandWindow:PushCommand(display)
    local lblVariableName = Label:New {
        caption = display,
        width = 100,
        x = 1,
        parent = self.commandsPanel,
        align = 'left',
    }
end

function CommandWindow:PopCommand()
    self.commandsPanel:RemoveChild(self.commandsPanel.children[#self.commandsPanel.children])
    self.commandsPanel:Invalidate()
end

function CommandWindow:ClearCommands()
    self.commandsPanel:ClearChildren()
end