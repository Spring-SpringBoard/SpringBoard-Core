StatusWindowModel = LCS.class{}

function StatusWindowModel:init()
    self.posStr = "Off-screen"
    self.selectionStr = "No selection"
    self.memoryStr = "Memory 0 MB"
    self.versionStr = ""
    self.update = 0
    self.warnedTime = nil
end

function StatusWindowModel:Initialize()
    SB.delay(function()
        SB.view.selectionManager:addListener(self)
        self:OnSelectionChanged()
    end)

    self:UpdateVersion()
end

function StatusWindowModel:Update()
    self:UpdateSelection()
    self:UpdateMemory()
    self.update = self.update + 1
end

function StatusWindowModel:UpdateSelection()
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local worldX, worldY, worldZ = coords[1], coords[2], coords[3]
        self.posStr = string.format("X: %d, Y: %d, Z: %d", worldX, worldY, worldZ)
    else
        self.posStr = "Off-screen"
    end
end

function StatusWindowModel:UpdateMemory()
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

    -- Detect extensive memory usage
    local color = SB.conf.STATUS_TEXT_OK_COLOR
    local memoryWarnLevel = 500
    if string.find(Engine.versionFull, "BIGMEM", nil, true) then
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

    self.memoryStr = "Memory " .. color .. ('%.0f'):format(memory) .. " MB\b"
    if videoMemoryStr then
        self.memoryStr = self.memoryStr .. " " .. videoMemoryStr
    end
end

function StatusWindowModel:UpdateVersion()
    local launcherVersion = SB_LAUNCHER_VERSION and (' (' .. SB_LAUNCHER_VERSION .. ')') or ''
    self.versionStr = Game.gameName .. "-" .. Game.gameVersion .. launcherVersion
end

function StatusWindowModel:OnSelectionChanged()
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

function StatusWindowModel:GetStatusText()
    return self.posStr .. ". " .. self.selectionStr
end

function StatusWindowModel:GetMemoryText()
    return self.memoryStr
end

function StatusWindowModel:GetVersionText()
    return self.versionStr
end
