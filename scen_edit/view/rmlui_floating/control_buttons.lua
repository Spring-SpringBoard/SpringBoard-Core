RmlUiControlButtons = LCS.class{}

function RmlUiControlButtons:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/control_buttons.rml')
    self.started = false
end

function RmlUiControlButtons:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self:UpdateStartStopButton()
    Log.Notice("Control Buttons initialized (RmlUi stub)")
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
    if not self.started then
        Log.Notice("Starting scenario (not implemented)")
        self:GameStarted()
        -- TODO: Execute StartCommand
    else
        Log.Notice("Stopping scenario (not implemented)")
        self:GameStopped()
        -- TODO: Execute StopCommand
    end
end

function RmlUiControlButtons:OnToggleUI()
    Log.Notice("Toggle UI visibility (not implemented)")
    -- TODO: SB.view:SetVisible(not SB.view.__visible)
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

function RmlUiControlButtons:GameStarted()
    self.started = true
    self:UpdateStartStopButton()
    Log.Notice("Game started")
end

function RmlUiControlButtons:GameStopped()
    self.started = false
    self:UpdateStartStopButton()
    Log.Notice("Game stopped")
end
