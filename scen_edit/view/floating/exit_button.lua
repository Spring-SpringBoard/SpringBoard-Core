ExitButton = LCS.class{}

function ExitButton:init()
    self.btnExit = Button:New {
        x = 5,
        y = 35,
        width = 100,
        height = 50,
        font = {
            size = 22,
            outline = true,
        },
        parent = screen0,
        caption = "Exit",
        OnClick = {
            function()
                Spring.SendCommands("quit", "quitforce")
            end
        }
    }
end
