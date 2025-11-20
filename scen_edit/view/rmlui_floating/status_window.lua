SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/status_window_model.lua'))

RmlUiStatusWindow = LCS.class{}

function RmlUiStatusWindow:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/status_window.rml')
    self.model = StatusWindowModel()

    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    assert(self.document, "Status Window failed to load document")

    -- Cache elements
    self.elements = {
        positionLabel = self.document:GetElementById("status-position"),
        memoryLabel = self.document:GetElementById("status-memory"),
        versionLabel = self.document:GetElementById("status-version"),
    }

    for name, element in pairs(self.elements) do
        assert(element, "Status Window missing element: " .. name)
    end

    -- Set version once
    self.elements.versionLabel.inner_rml = self.model:GetVersionString()

    -- Register view callbacks with model
    self.model.onStatusUpdate = function(statusText)
        self.elements.positionLabel.inner_rml = statusText
    end
    self.model.onMemoryUpdate = function(memoryStr, memory, color)
        -- Convert Chili color codes to HTML color
        local htmlColor = "#01b414"  -- Green (OK)
        if memory > 500 then
            htmlColor = "#ff1432"  -- Red (DANGER)
        elseif memory > 300 then
            htmlColor = "#96960a"  -- Yellow (WARN)
        end
        self.elements.memoryLabel.inner_rml = string.format('Memory <span style="color: %s;">%.0f MB</span>', htmlColor, memory)
    end
end

function RmlUiStatusWindow:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiStatusWindow:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiStatusWindow:Update()
    self.model:Update()
end
