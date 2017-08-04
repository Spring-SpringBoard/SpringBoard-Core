BottomBar = LCS.class{}

function BottomBar:init()
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
    }

    self.commandWindow = CommandWindow(self.window)
    self.statusWindow = StatusWindow(self.window)
    self.controlButtons = ControlButtons(self.window)
end

function BottomBar:Update()
    self.statusWindow:Update()
end
