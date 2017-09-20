StatusWindow = LCS.class{}

function StatusWindow:init(parent)
    self.lblStatus = Label:New {
        x = 0,
        bottom = 30,
        width = "100%",
        height = 20,
        caption = "",
        --valign = "ascender",
    }
    self.lblMemory = Label:New {
        x = 0,
        bottom = 0,
        width = "100%",
        height = 20,
        caption = "",
        --valign = "ascender",
    }
    self.statusWindow = Control:New {
        parent = parent,
        caption = "",
        x = 0,
        bottom = 10,
        width = 300,
        height = "100%",
        children = {
            self.lblStatus,
            self.lblMemory
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
        local worldX, worldZ = coords[1], coords[3]
        self.posStr = string.format("X: %d, Z: %d", worldX, worldZ)
    end

    self.lblStatus:SetCaption(self.posStr .. ". " .. self.selectionStr)
end

function StatusWindow:_UpdateMemory()
    if self.update % 60 ~= 0 then
        return
    end

    local memory = collectgarbage("count") / 1024
    local memoryStr = "Memory " .. ('%.0f'):format(memory) .. " MB"

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
