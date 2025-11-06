--- RmlUi Base Component
--- Simpler base class for RmlUi windows/components that aren't full dialogs
--- (pickers, floating windows, etc.)

RmlUiComponent = LCS.class{}

function RmlUiComponent:init(rmlPath, title)
    self.rmlPath = rmlPath
    self.title = title or "Component"
    self.document = nil
    self.visible = false
end

function RmlUiComponent:Initialize()
    if not SB.rmlui or not SB.rmlui.initialized then
        Log.Warning("RmlUi not initialized")
        return false
    end

    -- Load document
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    if not self.document then
        Log.Error("Failed to load component: " .. self.rmlPath)
        return false
    end

    -- Set title if there's a title element
    local titleElement = self.document:GetElementById("component-title")
    if titleElement then
        titleElement.inner_rml = self.title
    end

    Log.Notice(self.title .. " component initialized")
    return true
end

function RmlUiComponent:Show()
    if not self.document then
        if not self:Initialize() then
            return
        end
    end

    self.document:Show()
    self.visible = true
end

function RmlUiComponent:Hide()
    if self.document then
        self.document:Hide()
        self.visible = false
    end
end

function RmlUiComponent:Close()
    if self.document then
        self.document:Close()
        self.document = nil
        self.visible = false
    end
end

function RmlUiComponent:IsVisible()
    return self.visible
end
