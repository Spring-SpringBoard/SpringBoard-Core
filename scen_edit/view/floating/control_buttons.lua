ControlButtons = LCS.class{}

function ControlButtons:init(parent)
    self.started = false --FIXME: check instead of assuming
    self.btnStartStop = Button:New {
        caption='',
        bottom = 5,
        x = 0,
        height = 45,
        width = 45,
        backgroundColor = SB.conf.BTN_ADD_COLOR,
        OnClick = {
            function()
                if not self.started then
                    local cmd = StartCommand()
                    SB.commandManager:execute(cmd)
                    self:GameStarted()
                else
                    local cmd = StopCommand()
                    SB.commandManager:execute(cmd)
                    self:GameStopped()
                end
            end
        }
    }
    self:UpdateStartStopButton()

    self.window = Control:New {
        parent = parent,
        caption = "",
        right = 400,
        bottom = 10,
        width = 75,
        height = "100%",
        children = {
            self.btnStartStop,
        }
    }
end

function ControlButtons:UpdateStartStopButton()
    self.btnStartStop:ClearChildren()
    if not self.started then
        self.btnStartStop.tooltip = "Start scenario"
        self.btnStartStop:AddChild(
            Image:New {
                file = SB_IMG_DIR .. "play-button.png",
                height = SB.conf.B_HEIGHT - 2,
                width = SB.conf.B_HEIGHT - 2,
                margin = {0, 0, 0, 0},
            }
        )
    else
        self.btnStartStop.tooltip = "Stop scenario"
        self.btnStartStop:AddChild(
            Image:New {
                file = SB_IMG_DIR .. "stop-button.png",
                height = SB.conf.B_HEIGHT - 2,
                width = SB.conf.B_HEIGHT - 2,
                margin = {0, 0, 0, 0},
            }
        )
    end
end

function ControlButtons:GameStarted()
    self.started = true
    self:UpdateStartStopButton()
    self.btnStartStop.backgroundColor = SB.conf.BTN_CANCEL_COLOR
    self.btnStartStop.Update = function(self, ...)
        Chili.Button.Update(self, ...)
        self.backgroundColor = SB.deepcopy(SB.conf.BTN_CANCEL_COLOR)
        self.backgroundColor[4] = 0.5 + math.abs(2 * math.sin(os.clock())) / math.pi
        self:Invalidate()
        self:RequestUpdate()
    end
end

function ControlButtons:GameStopped()
    self.started = false
    self:UpdateStartStopButton()
    self.btnStartStop.backgroundColor = SB.conf.BTN_ADD_COLOR
    self.btnStartStop.Update = Chili.Button.Update
end
