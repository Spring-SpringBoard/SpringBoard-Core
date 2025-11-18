RmlUiControlButtons = LCS.class{}

function RmlUiControlButtons:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/control_buttons.rml')
    self.started = false  -- FIXME: check instead of assuming
    self.__lastFrame = nil
end

function RmlUiControlButtons:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self:UpdateStartStopButton()
    self:UpdateGameDrawing()
    Log.Notice("Control Buttons initialized (RmlUi)")
    return true
end

function RmlUiControlButtons:BindEvents()
    local btnStartStop = self.document:GetElementById("btn-start-stop")
    if btnStartStop then
        btnStartStop:AddEventListener("click", function()
            self:OnStartStop()
        end)
    end

    local btnToggleUI = self.document:GetElementById("btn-toggle-ui")
    if btnToggleUI then
        btnToggleUI:AddEventListener("click", function()
            self:OnToggleUI()
        end)
    end
end

function RmlUiControlButtons:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiControlButtons:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiControlButtons:OnStartStop()
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

function RmlUiControlButtons:OnToggleUI()
    SB.view:SetVisible(not SB.view.__visible)
end

function RmlUiControlButtons:UpdateStartStopButton()
    local btn = self.document:GetElementById("btn-start-stop")
    if not btn then return end

    if not self.started then
        btn.inner_rml = "▶"
        btn:SetAttribute("title", "Start scenario")
        btn:RemoveClass("stop")
    else
        btn.inner_rml = "■"
        btn:SetAttribute("title", "Stop scenario")
        btn:AddClass("stop")
    end
end

-- All this better belongs to some command/model
function RmlUiControlButtons:UpdateGameDrawing()
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

function RmlUiControlButtons:GameStarted()
    self.started = true
    self:UpdateStartStopButton()
    self:UpdateGameDrawing()
end

function RmlUiControlButtons:GameStopped()
    self.started = false
    self:UpdateStartStopButton()
    self:UpdateGameDrawing()
end
