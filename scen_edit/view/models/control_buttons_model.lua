ControlButtonsModel = LCS.class{}

function ControlButtonsModel:init()
    self.started = false  -- FIXME: check instead of assuming
    self.__lastFrame = nil
    self.listeners = {}
end

function ControlButtonsModel:Initialize()
    self:UpdateGameDrawing()
end

function ControlButtonsModel:AddListener(listener)
    table.insert(self.listeners, listener)
end

function ControlButtonsModel:NotifyListeners(event, ...)
    for _, listener in ipairs(self.listeners) do
        if listener[event] then
            listener[event](listener, ...)
        end
    end
end

function ControlButtonsModel:OnStartStop()
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

function ControlButtonsModel:OnToggleUI()
    SB.view:SetVisible(not SB.view.__visible)
end

-- All this better belongs to some command/model
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

function ControlButtonsModel:GameStarted()
    self.started = true
    self:UpdateGameDrawing()
    self:NotifyListeners("OnGameStarted")
end

function ControlButtonsModel:GameStopped()
    self.started = false
    self:UpdateGameDrawing()
    self:NotifyListeners("OnGameStopped")
end

function ControlButtonsModel:IsStarted()
    return self.started
end
