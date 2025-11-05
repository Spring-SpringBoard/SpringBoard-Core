RmlUiStatusWindow = LCS.class{}

function RmlUiStatusWindow:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/status_window.rml')
    self.posStr = "Off-screen"
    self.selectionStr = "No selection"
    self.update = 0
end

function RmlUiStatusWindow:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)
    Log.Notice("Status Window initialized (RmlUi stub)")
    return true
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
    if not self.document then return end

    self:_UpdateSelection()
    self:_UpdateMemory()
    self:_UpdateVersion()

    self.update = self.update + 1
end

function RmlUiStatusWindow:_UpdateSelection()
    -- Stub: Get mouse position and selection
    local posElement = self.document:GetElementById("status-position")
    if posElement then
        local x, y = Spring.GetMouseState()
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            local worldX, worldY, worldZ = coords[1], coords[2], coords[3]
            self.posStr = string.format("X: %d, Y: %d, Z: %d", worldX, worldY, worldZ)
        else
            self.posStr = "Off-screen"
        end

        posElement.inner_rml = self.posStr .. ". " .. self.selectionStr
    end
end

function RmlUiStatusWindow:_UpdateMemory()
    if self.update % 60 ~= 0 then
        return
    end

    local memElement = self.document:GetElementById("status-memory")
    if memElement then
        local memory
        if Spring.GetLuaMemUsage then
            local memoryInStates = {Spring.GetLuaMemUsage()}
            memory = memoryInStates[3] / 1024
        else
            memory = collectgarbage("count") / 1024
        end

        memElement.inner_rml = string.format("Memory %.0f MB", memory)
    end
end

function RmlUiStatusWindow:_UpdateVersion()
    local versionElement = self.document:GetElementById("status-version")
    if versionElement then
        local launcherVersion = SB_LAUNCHER_VERSION and (' (' .. SB_LAUNCHER_VERSION .. ')') or ''
        versionElement.inner_rml = Game.gameName .. "-" .. Game.gameVersion .. launcherVersion
    end
end

function RmlUiStatusWindow:OnSelectionChanged()
    -- Stub: Update selection string
    local selCount = 0 -- TODO: Get from selection manager
    if selCount == 1 then
        self.selectionStr = "Selected: 1"
    elseif selCount > 0 then
        self.selectionStr = string.format("Selected: %d", selCount)
    else
        self.selectionStr = "No selection"
    end
end
