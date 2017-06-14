RuntimeView = LCS.class{}

function RuntimeView:init()
    self.started = false --FIXME: check instead of assuming
    self.btnStartStop = Button:New {
        caption='',
        y = 1,
        x = 1,
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
    self.dvv = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self.dtv = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self.btnToggleShowDevelop = Button:New {
        caption='Hide dev view',
        x = 55,
        y = 1,
        width= 110,
        height = SB.conf.B_HEIGHT + 20,
        tooltip = "Toggle displaying of debugging symbols",
        OnClick = {
            function()
                SB.view.displayDevelop = not SB.view.displayDevelop
                if SB.view.displayDevelop then
                    self.btnToggleShowDevelop.caption = 'Hide dev view'
                else
                    self.btnToggleShowDevelop.caption = 'Show dev view'
                end
            end
        }
    }
    self.runtimeViewWindow = Window:New {
        parent = screen0,
        caption = "Runtime Window",
        right = 501,
        bottom = 0,
        resizable = false,
        draggable = false,
        width = 375,
        height = 200,
        children = {
            Control:New {
                orientation = 'horizontal',
                width = '100%',
                y = 10,
                height = SB.conf.B_HEIGHT * 2,
                padding = {0,0,0,0},
                itemPadding = {0,10,10,10},
                itemMargin = {0,0,0,0},
                children = {
                    self.btnStartStop,
                    self.btnToggleShowDevelop,
                },
            },
            StackPanel:New {
                y = SB.conf.B_HEIGHT * 2 + 10,
                x = 1,
                right = 1,
                bottom = 1,
                itemMargin = {0, 0, 0, 0},
                children = {
                    ScrollPanel:New {
                        width = "100%",
                        height = "100%",
                        children = {
                            self.dvv,
                        },
                    },
                    ScrollPanel:New {
                        width = "100%",
                        height = "100%",
                        children = {
                            self.dtv,
                        },
                    },
                },
            },
        }
    }
    self:Populate()
end

function RuntimeView:Populate()
    DebugTriggerView(self.dtv)
    DebugVariableView(self.dvv)
end

function RuntimeView:UpdateStartStopButton()
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

function RuntimeView:GameStarted()
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

function RuntimeView:GameStopped()
    self.started = false
    self:UpdateStartStopButton()
    self.btnStartStop.backgroundColor = SB.conf.BTN_ADD_COLOR
    self.btnStartStop.Update = Chili.Button.Update
end