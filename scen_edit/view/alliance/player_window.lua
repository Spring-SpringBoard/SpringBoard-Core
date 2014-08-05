PlayerWindow = LCS.class{}

function PlayerWindow:init(team)
    self.team = team

    self.lblName = Label:New {
        x = 5,
        y = 15,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 50,
        caption = "Name:",
    }
    self.ebName = EditBox:New {
        x = 65,
        y = 15,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 200,
        text = team.name,
    }

    self.cbAI = Checkbox:New {
        x = 5,
        y = SCEN_EDIT.conf.B_HEIGHT + 25,
        height = SCEN_EDIT.conf.B_HEIGHT,
        width = 70,
        checked = not not team.ai,
        caption = "AI",
    }

    self.lblColor = Label:New {
        x = 5,
        y = 2 * SCEN_EDIT.conf.B_HEIGHT + 35,
        height = 60,
        width = 50,
        caption = "Color:",
    }
    self.clbColor = Chili.Colorbars:New {
        x = 65,
        y = 2 * SCEN_EDIT.conf.B_HEIGHT + 35,
        height = 60,
        width = 300,
        color = {team.color.r, team.color.g, team.color.b, team.color.a},
    }
    self.btnClose = Button:New {
        caption = 'Close',
        width = 100,
        right = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        OnClick = { function() self.window:Dispose() end }
    }
    self.window = Window:New {
        width = 400,
        height = 220,
        resizable = false,
        parent = screen0,
        caption = "Player",
        x = 500,
        y = 200,
        children = {
            self.lblName,
            self.ebName,
            self.cbAI,
            self.lblColor,
            self.clbColor,
            self.btnClose,
        },
        OnDispose = { 
            function()
                local newTeam = SCEN_EDIT.deepcopy(team)
                newTeam.name = self.ebName.text
                local clbColor = self.clbColor.color
                newTeam.color.r = clbColor[1]
                newTeam.color.g = clbColor[2]
                newTeam.color.b = clbColor[3]
                newTeam.color.a = clbColor[4]
                newTeam.ai = self.cbAI.checked
                local cmd = UpdateTeamCommand(newTeam)
                SCEN_EDIT.commandManager:execute(cmd)
            end
        },
    }
end
