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
    self:UpdateStartStopButton()

    local x
    local y
    local bottom, right
    pcall(function()
        local startStop = SB.model.game.startStop
        right = startStop.right
        bottom = startStop.bottom
        Spring.Echo("bottom", bottom)
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
        width = 70,
        height = 70,
        children = {
            self.btnStartStop,
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
        pcall(function()
            local OnStopEditingUnsynced = SB.model.game.OnStopEditingUnsynced
            if OnStopEditingUnsynced then
                OnStopEditingUnsynced()
            end
        end)
    else
        pcall(function()
            local OnStartEditingUnsynced = SB.model.game.OnStartEditingUnsynced
            if OnStartEditingUnsynced then
                OnStartEditingUnsynced()
            end
        end)
    end

    -- This relies on *game* Chili, not SB
    -- If game doesn't use Chili, we don't control its drawing
    if not WG.Chili then
        return
    end
    if not self.started then
        -- Disable game drawing
        self.__oldDraw = WG.Chili.Screen0.Draw or WG.Chili.Screen.Draw
        WG.Chili.Screen0.Draw = function() end
    else
        WG.Chili.Screen0.Draw = self.__oldDraw or WG.Chili.Screen.Draw
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
    self.btnStartStop.Update = function(self, ...)
        Chili.Button.Update(self, ...)
        self.backgroundColor = SB.deepcopy(SB.conf.BTN_CANCEL_COLOR)
        self.backgroundColor[4] = 0.5 + math.abs(2 * math.sin(os.clock())) / math.pi
        self:Invalidate()
        self:RequestUpdate()
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
