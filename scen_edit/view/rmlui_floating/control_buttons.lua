RmlUiControlButtons = LCS.class{}

function RmlUiControlButtons:init(model)
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/control_buttons.rml')
    self.model = model or ControlButtonsModel()
end

function RmlUiControlButtons:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    self:BindEvents()
    self.model:AddListener(self)
    self.model:Initialize()
    self:UpdateStartStopButton()
    Log.Notice("Control Buttons initialized (RmlUi)")
    return true
end

function RmlUiControlButtons:BindEvents()
    local btnStartStop = self.document:GetElementById("btn-start-stop")
    if btnStartStop then
        btnStartStop:AddEventListener("click", function()
            self.model:OnStartStop()
        end)
    end

    local btnToggleUI = self.document:GetElementById("btn-toggle-ui")
    if btnToggleUI then
        btnToggleUI:AddEventListener("click", function()
            self.model:OnToggleUI()
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

function RmlUiControlButtons:UpdateStartStopButton()
    local btn = self.document:GetElementById("btn-start-stop")
    if not btn then return end

    if not self.model:IsStarted() then
        btn.inner_rml = "▶"
        btn:SetAttribute("title", "Start scenario")
        btn:RemoveClass("stop")
    else
        btn.inner_rml = "■"
        btn:SetAttribute("title", "Stop scenario")
        btn:AddClass("stop")
    end
end

-- Model callbacks
function RmlUiControlButtons:OnGameStarted()
    self:UpdateStartStopButton()
end

function RmlUiControlButtons:OnGameStopped()
    self:UpdateStartStopButton()
end
