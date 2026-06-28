StatusWindowModel = LCS.class{}

function StatusWindowModel:init()
    self.posStr = ""
    self.selectionStr = ""
    self.memoryStr = ""
    self.versionStr = ""
    self.update = 0
    self.warnedTime = nil

    -- Callbacks for view updates
    self.onStatusUpdate = nil
    self.onMemoryUpdate = nil

    -- Register as selection listener
    SB.delay(function()
        if SB.view and SB.view.selectionManager then
            SB.view.selectionManager:addListener(self)
            self:OnSelectionChanged()
        end
    end)

    -- Set version string
    local launcherVersion = SB_LAUNCHER_VERSION and (' (' .. SB_LAUNCHER_VERSION .. ')') or ''
    self.versionStr = Game.gameName .. "-" .. Game.gameVersion .. launcherVersion
end

function StatusWindowModel:GetVersionString()
    return self.versionStr
end

function StatusWindowModel:Update()
    self:_UpdateSelection()
    self:_UpdateMemory()
    self.update = self.update + 1
end

function StatusWindowModel:_UpdateSelection()
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local worldX, worldY, worldZ = coords[1], coords[2], coords[3]
        self.posStr = string.format("X: %d, Y: %d Z: %d", worldX, worldY, worldZ)
    else
        self.posStr = "Off-screen"
    end

    local statusText = self.posStr .. ". " .. self.selectionStr

    if self.onStatusUpdate then
        self.onStatusUpdate(statusText)
    end
end

function StatusWindowModel:_UpdateMemory()
    if self.update % 60 ~= 0 then
        return
    end

    local videoMemoryStr
    if Spring.GetVidMemUsage then
        local vram, vramMax = Spring.GetVidMemUsage()
        videoMemoryStr = ("Video memory: %.0f/%.0f MB"):format(vram, vramMax)
    end

    local memory
    if Spring.GetLuaMemUsage then
        local memoryInStates = {Spring.GetLuaMemUsage()}
        memory = memoryInStates[3] / 1024
    else
        memory = collectgarbage("count") / 1024
    end

    local color = SB.conf.STATUS_TEXT_OK_COLOR
    local memoryWarnLevel = 500
    if string.find(Engine.versionFull or "", "BIGMEM", nil, true) then
        memoryWarnLevel = 16000
    end

    if memory > memoryWarnLevel then
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

    self.memoryStr = memoryStr

    if self.onMemoryUpdate then
        self.onMemoryUpdate(memoryStr, memory, color)
    end
end

function StatusWindowModel:OnSelectionChanged()
    if not SB.view or not SB.view.selectionManager then
        self.selectionStr = "No selection"
        return
    end

    local selCount = SB.view.selectionManager:GetSelectionCount()
    if selCount == 1 then
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
