ControlButtonsModel = LCS.class{}

function ControlButtonsModel:init()
    self.started = false

    -- Callbacks for view updates
    self.onGameStarted = nil
    self.onGameStopped = nil
end

function ControlButtonsModel:IsStarted()
    return self.started
end

function ControlButtonsModel:ToggleStartStop()
    if not self.started then
        self:ExecuteStart()
    else
        self:ExecuteStop()
    end
end

function ControlButtonsModel:ExecuteStart()
    local frame = Spring.GetGameFrame()
    if self.__lastFrame then
        if frame - self.__lastFrame < 15 then
            return
        end
    end
    self.__lastFrame = frame

    local cmd = StartCommand()
    SB.commandManager:execute(cmd)
    self:GameStarted()
end

function ControlButtonsModel:ExecuteStop()
    local frame = Spring.GetGameFrame()
    if self.__lastFrame then
        if frame - self.__lastFrame < 15 then
            return
        end
    end
    self.__lastFrame = frame

    local cmd = StopCommand()
    SB.commandManager:execute(cmd)
    self:GameStopped()
end

function ControlButtonsModel:GameStarted()
    self.started = true

    if self.onGameStarted then
        self.onGameStarted()
    end

    self:UpdateGameDrawing()
end

function ControlButtonsModel:GameStopped()
    self.started = false

    if self.onGameStopped then
        self.onGameStopped()
    end

    self:UpdateGameDrawing()
end

function ControlButtonsModel:UpdateGameDrawing()
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

function ControlButtonsModel:ToggleUIVisibility()
    if SB.view then
        SB.view:SetVisible(not SB.view.__visible)
    end
end
