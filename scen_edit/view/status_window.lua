StatusWindow = LCS.class{}

function StatusWindow:init()
    self.lblStatus = Label:New {
        x = 0,
        y = 0,
        width = "100%",
        height = "100%",
        caption = "",
    }
    self.statusWindow = Window:New {
        parent = screen0,
        caption = "",
        --right = 500 + 375 + 375,
        x = 0,
        bottom = 0,
        resizable = false,
        draggable = false,
        width = 230,
        height = 50,
        children = {
            self.lblStatus
        }
    }

    SB.delay(function()
        SB.view.selectionManager:addListener(self)
        self:OnSelectionChanged(SB.view.selectionManager:GetSelection())
    end)

    self.posStr = ""
    self.selectionStr = ""
end

function StatusWindow:_UpdateStatus()
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground"  then
        local worldX, worldZ = coords[1], coords[3]
        self.posStr = string.format("X: %d, Z: %d", worldX, worldZ)
    end

    self.lblStatus:SetCaption(self.posStr .. ". " .. self.selectionStr)
end

function StatusWindow:Update()
    self:_UpdateStatus()
end

function StatusWindow:OnSelectionChanged(selection)
    local selObjectsCount = #selection.units + #selection.features + #selection.areas
    if selObjectsCount > 0 then
        self.selectionStr = string.format("Selected: %d", selObjectsCount)
    else
        self.selectionStr = "No selection"
    end
end
