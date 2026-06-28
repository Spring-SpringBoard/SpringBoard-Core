SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/control_buttons_model.lua'))

ControlButtons = LCS.class{}

function ControlButtons:init(parent)
    self.model = ControlButtonsModel()

    self.btnStartStop = Button:New {
        caption='',
        y = 0,
        x = 0,
        height = 45,
        width = 45,
        backgroundColor = SB.conf.BTN_ADD_COLOR,
        OnClick = {
            function()
                self.model:ToggleStartStop()
            end
        }
    }
    self.btnShowToggle = Button:New {
        caption = '',
        tooltip = 'Toggle editor display',
        y = 5,
        x = 60,
        height = 35,
        width = 35,
        -- backgroundColor = SB.conf.BTN_ADD_COLOR,
        OnClick = {
            function()
                self.model:ToggleUIVisibility()
            end
        },
        children = {
            Image:New {
                file = Path.Join(SB.DIRS.IMG, 'trigger-inspect.png'),
                height = SB.conf.B_HEIGHT - 2 - 3,
                width = SB.conf.B_HEIGHT - 2 - 3,
                margin = {0, 0, 0, 0},
            }
        },
    }

    -- Register view callbacks with model
    self.model.onGameStarted = function()
        self:OnGameStarted()
    end
    self.model.onGameStopped = function()
        self:OnGameStopped()
    end

    self:UpdateStartStopButton()

    local x
    local y
    local bottom, right
    pcall(function()
        local startStop = SB.model.game.startStop
        right = startStop.right
        bottom = startStop.bottom
        if not right then
            x = startStop.x
        end
        if not bottom then
            y = startStop.y
        end
    end)
    if not bottom and not y then
        y = 10
    end
    if not right and not x then
        x = "45%"
    end

    self.window = Control:New {
        parent = screen0,
        caption = "",
        x = x,
        y = y,
        bottom = bottom,
        right = right,
        width = 150,
        height = 70,
        children = {
            self.btnStartStop,
            self.btnShowToggle
        }
    }
end

function ControlButtons:UpdateStartStopButton()
    self.btnStartStop:ClearChildren()
    if not self.model:IsStarted() then
        self.btnStartStop.tooltip = "Start scenario"
        self.btnStartStop:AddChild(
            Image:New {
                file = Path.Join(SB.DIRS.IMG, 'play-button.png'),
                height = SB.conf.B_HEIGHT - 2,
                width = SB.conf.B_HEIGHT - 2,
                margin = {0, 0, 0, 0},
            }
        )
    else
        self.btnStartStop.tooltip = "Stop scenario"
        self.btnStartStop:AddChild(
            Image:New {
                file = Path.Join(SB.DIRS.IMG, 'stop-button.png'),
                height = SB.conf.B_HEIGHT - 2,
                width = SB.conf.B_HEIGHT - 2,
                margin = {0, 0, 0, 0},
            }
        )
    end
end

function ControlButtons:OnGameStarted()
    self:UpdateStartStopButton()
    self.btnStartStop.backgroundColor = SB.conf.BTN_CANCEL_COLOR
    self.btnStartStop.Update = function(obj, ...)
        Chili.Button.Update(obj, ...)
        obj.backgroundColor = Table.DeepCopy(SB.conf.BTN_CANCEL_COLOR)
        obj.backgroundColor[4] = 0.5 + math.abs(2 * math.sin(os.clock())) / math.pi
        obj:Invalidate()
        obj:RequestUpdate()
    end
end

function ControlButtons:OnGameStopped()
    self:UpdateStartStopButton()
    self.btnStartStop.backgroundColor = SB.conf.BTN_ADD_COLOR
    self.btnStartStop.Update = Chili.Button.Update
end
