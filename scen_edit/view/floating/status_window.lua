StatusWindow = LCS.class{}

function StatusWindow:init(parent)
    self.lblStatus = Label:New {
        x = 0,
        bottom = 50,
        width = "100%",
        height = 20,
        caption = "",
    }
    self.lblMemory = Label:New {
        x = 0,
        bottom = 25,
        width = "100%",
        height = 30,
        caption = "",
    }
    local launcherVersion
    if SB_LAUNCHER_VERSION ~= nil then
        launcherVersion = ' (' .. SB_LAUNCHER_VERSION .. ')'
    else
        launcherVersion = ''
    end
    self.lblSpringBoard = Label:New {
        x = 0,
        bottom = 0,
        width = "100%",
        height = 20,
        caption = Game.gameName .. "-" .. Game.gameVersion .. launcherVersion,
        --valign = "ascender",
    }
    self.statusWindow = Control:New {
        parent = parent,
        caption = "",
        x = 0,
        bottom = 0,
        width = 400,
        height = "100%",
        children = {
            self.lblStatus,
            self.lblMemory,
            self.lblSpringBoard
        }
    }

    SB.delay(function()
        SB.view.selectionManager:addListener(self)
        self:OnSelectionChanged()
    end)

    self.posStr = ""
    self.selectionStr = ""

    self.update = 0
end

function StatusWindow:_UpdateSelection()
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground"  then
        local worldX, worldY, worldZ = coords[1], coords[2], coords[3]
        self.posStr = string.format("X: %d, Y: %d Z: %d", worldX, worldY, worldZ)
    else
        self.posStr = "Off-screen"
    end

    self.lblStatus:SetCaption(self.posStr .. ". " .. self.selectionStr)
end

function StatusWindow:_UpdateMemory()
    if self.update % 60 ~= 0 then
        return
    end

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
    -- TODO: Act on it a bit better and automatically clear the undo-redo stack instead of prompting the user to do stuff.
    local color = SB.conf.STATUS_TEXT_OK_COLOR
    if memory > 500 then
        color = SB.conf.STATUS_TEXT_DANGER_COLOR
        if not self.warnedTime or os.clock() - self.warnedTime > 10 then
            self.warnedTime = os.clock()
            WG.Chotify:Post({
                -- FIXME: The white line after Danger is an ugly hack - seems to be an Editbox issue with multi-line coloring
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

    self.lblMemory:SetCaption(memoryStr)
end

function StatusWindow:Update()
    self:_UpdateSelection()
    self:_UpdateMemory()

    self.update = self.update + 1
end

function StatusWindow:OnSelectionChanged()
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
