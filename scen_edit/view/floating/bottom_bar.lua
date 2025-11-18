BottomBar = LCS.class{}

function BottomBar:init(models)
    -- Create or use provided models
    self.models = models or {
        statusWindow = StatusWindowModel(),
        commandWindow = CommandWindowModel(),
        controlButtons = ControlButtonsModel(),
    }

    self.window = Window:New {
        parent = screen0,
        caption = "",
        x = 0,
        right = 500,
        bottom = 0,
        resizable = false,
        draggable = false,
        width = 400,
        height = SB.conf.BOTTOM_BAR_HEIGHT,
        padding = {0, 0, 0, 0},
        classname = 'sb_window',
    }

    self.commandWindow = CommandWindow(self.window, self.models.commandWindow)
    self.statusWindow = StatusWindow(self.window, self.models.statusWindow)
    self.controlButtons = ControlButtons(nil, self.models.controlButtons)
end

function BottomBar:Update()
    self.statusWindow:Update()
end
