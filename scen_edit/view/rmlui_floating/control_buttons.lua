SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/control_buttons_model.lua'))

RmlUiControlButtons = LCS.class{}

function RmlUiControlButtons:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/control_buttons.rml')
    self.model = ControlButtonsModel()

    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    assert(self.document, "Control Buttons failed to load document")

    -- Cache elements
    self.elements = {
        btnStartStop = self.document:GetElementById("btn-start-stop"),
        btnToggleUI = self.document:GetElementById("btn-toggle-ui"),
    }

    for name, element in pairs(self.elements) do
        assert(element, "Control Buttons missing element: " .. name)
    end

    -- Register view callbacks with model
    self.model.onGameStarted = function()
        self:OnGameStarted()
    end
    self.model.onGameStopped = function()
        self:OnGameStopped()
    end

    self:BindEvents()
    self:UpdateStartStopButton()
end

function RmlUiControlButtons:BindEvents()
    self.elements.btnStartStop:AddEventListener("click", function()
        self.model:ToggleStartStop()
    end)

    self.elements.btnToggleUI:AddEventListener("click", function()
        self.model:ToggleUIVisibility()
    end)
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
    if not self.model:IsStarted() then
        self.elements.btnStartStop.inner_rml = '<img src="../../../../LuaUI/images/scenedit/play-button.png"/>'
        self.elements.btnStartStop:SetAttribute("title", "Start scenario")
        self.elements.btnStartStop:SetClass("stop", false)
    else
        self.elements.btnStartStop.inner_rml = '<img src="../../../../LuaUI/images/scenedit/stop-button.png"/>'
        self.elements.btnStartStop:SetAttribute("title", "Stop scenario")
        self.elements.btnStartStop:SetClass("stop", true)
    end
end

function RmlUiControlButtons:OnGameStarted()
    self:UpdateStartStopButton()
end

function RmlUiControlButtons:OnGameStopped()
    self:UpdateStartStopButton()
end
