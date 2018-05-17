ControlButtons = LCS.class{}

function ControlButtons:init(parent)
    self.started = false --FIXME: check instead of assuming
    self.btnStartStop = Button:New {
        caption='',
        y = 0,
        x = 0,
        height = 45,
        width = 45,
        backgroundColor = SB.conf.BTN_ADD_COLOR,
        OnClick = {
            function()
                local frame = Spring.GetGameFrame()
                if self.__lastFrame then
                    if frame - self.__lastFrame < 15 then
                        return
                    end
                end
                self.__lastFrame = frame

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
                SB.view:SetVisible(not SB.view.__visible)
            end
        },
        children = {
            Image:New {
                file = SB_IMG_DIR .. "trigger-inspect.png",
                height = SB.conf.B_HEIGHT - 2 - 3,
                width = SB.conf.B_HEIGHT - 2 - 3,
                margin = {0, 0, 0, 0},
            }
        },
    }
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

    self:UpdateGameDrawing()
end

-- All this better belongs to some command/model
function ControlButtons:UpdateGameDrawing()
    -- show/hide SB GUI
    if SB.view then
        if not self.started then
            SB.view:SetVisible(true)
        else
            SB.view:SetVisible(false)
        end
    end

    if self.started then
        SB.delay(function()
            local success, msg = pcall(function()
                local OnStopEditingUnsynced = SB.model.game.OnStopEditingUnsynced
                if OnStopEditingUnsynced then
                    OnStopEditingUnsynced()
                end
            end)
            if not success then
                Log.Error(msg)
                Log.Error("Error in custom OnStopEditingUnsynced")
            end
        end)
    else
        SB.delay(function()
            local success, msg = pcall(function()
                local OnStartEditingUnsynced = SB.model.game.OnStartEditingUnsynced
                if OnStartEditingUnsynced then
                    OnStartEditingUnsynced()
                end
            end)
            if not success then
                Log.Error(msg)
                Log.Error("Error in custom OnStartEditingUnsynced")
            end
        end)
    end
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
    self.btnStartStop.Update = function(obj, ...)
        Chili.Button.Update(obj, ...)
        obj.backgroundColor = SB.deepcopy(SB.conf.BTN_CANCEL_COLOR)
        obj.backgroundColor[4] = 0.5 + math.abs(2 * math.sin(os.clock())) / math.pi
        obj:Invalidate()
        obj:RequestUpdate()
    end

    self:UpdateGameDrawing()
end

function ControlButtons:GameStopped()
    self.started = false
    self:UpdateStartStopButton()
    self.btnStartStop.backgroundColor = SB.conf.BTN_ADD_COLOR
    self.btnStartStop.Update = Chili.Button.Update

    self:UpdateGameDrawing()
end
