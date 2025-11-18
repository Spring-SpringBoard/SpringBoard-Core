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
    self.document:GetElementById("btn-start-stop"):AddEventListener("click", function()
        self.model:OnStartStop()
    end)
    self.document:GetElementById("btn-toggle-ui"):AddEventListener("click", function()
        self.model:OnToggleUI()
    end)
end

function RmlUiControlButtons:Show()
    self.document:Show()
end

function RmlUiControlButtons:Hide()
    self.document:Hide()
end

function RmlUiControlButtons:UpdateStartStopButton()
    local btn = self.document:GetElementById("btn-start-stop")
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
