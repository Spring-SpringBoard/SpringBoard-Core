RmlUiStatusWindow = LCS.class{}

function RmlUiStatusWindow:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/status_window.rml')
    self.posStr = "Off-screen"
    self.selectionStr = "No selection"
    self.update = 0
end

function RmlUiStatusWindow:Initialize()
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)

    SB.delay(function()
        SB.view.selectionManager:addListener(self)
        self:OnSelectionChanged()
    end)

    Log.Notice("Status Window initialized (RmlUi)")
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
    if not memElement then return end

    local videoMemoryStr
    -- Compatibility
    if Spring.GetVidMemUsage then
        local vram, vramMax = Spring.GetVidMemUsage()
        videoMemoryStr = ("Video memory: %.0f/%.0f MB"):format(vram, vramMax)
    end

    local memory
    -- Compatibility
    if Spring.GetLuaMemUsage then
        local memoryInStates = {Spring.GetLuaMemUsage()}
        -- total memory is stored in the first value
        memory = memoryInStates[3] / 1024
    else
        memory = collectgarbage("count") / 1024
    end

    -- We're detecting extensive memory usage here and exiting the current state if critical.
    local color = SB.conf.STATUS_TEXT_OK_COLOR

    -- If the BIGMEM BAR105 engine build is used, then we dont ever really need to warn the user.
    local memoryWarnLevel = 500
    if string.find(Engine.versionFull,"BIGMEM", nil, true) then memoryWarnLevel = 16000 end
    if memory > memoryWarnLevel  then
        color = SB.conf.STATUS_TEXT_DANGER_COLOR
        if not self.warnedTime or os.clock() - self.warnedTime > 10 then
            self.warnedTime = os.clock()
            WG.Chotify:Post({
                body = SB.conf.STATUS_TEXT_DANGER_COLOR .. "Danger:\b\255\255\255\255 Large memory usage, may lead to a crash if it increases further.\n\n" ..
                       "Consider clearing the undo-redo stack to free memory.\b",
                title = "Low Memory",
                time = 10,
            })
            SB.stateManager:SetState(DefaultState())
        end
    elseif memory > 300 then
        color = SB.conf.STATUS_TEXT_WARN_COLOR
    end

    local memoryStr = "Memory " .. color .. ('%.0f'):format(memory) .. " MB\b"
    if videoMemoryStr then
        memoryStr = memoryStr .. " " .. videoMemoryStr
    end

    memElement.inner_rml = memoryStr
end

function RmlUiStatusWindow:_UpdateVersion()
    local versionElement = self.document:GetElementById("status-version")
    if versionElement then
        local launcherVersion = SB_LAUNCHER_VERSION and (' (' .. SB_LAUNCHER_VERSION .. ')') or ''
        versionElement.inner_rml = Game.gameName .. "-" .. Game.gameVersion .. launcherVersion
    end
end

function RmlUiStatusWindow:OnSelectionChanged()
    local selCount = SB.view.selectionManager:GetSelectionCount()
    if selCount == 1 then
        -- FIXME: selectionManager could use a utility function to get just one objectID
        local selection = SB.view.selectionManager:GetSelection()
        local objectID
        for _, v in pairs(selection) do
            if v and #v == 1 then
                objectID = v[1]
            end
        end
        self.selectionStr = string.format("Selected : 1 (ID=%d)", objectID)
    elseif selCount > 0 then
        self.selectionStr = string.format("Selected: %d", selCount)
    else
        self.selectionStr = "No selection"
    end
end
